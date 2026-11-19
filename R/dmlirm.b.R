# jamovi analysis class: double machine learning, interactive regression model (binary treatment): ATE and ATT.

dmlirmClass <- R6::R6Class(
    "dmlirmClass",
    inherit = dmlirmBase,
    private = list(

        .run = function() {
            o <- self$options
            dml_show_text(self$results, o, "dmlirm")
            if (is.null(o$outcome) || is.null(o$treat) || length(o$covs) == 0) {
                self$results$notes$setContent("<p>Select an outcome, a binary treatment and at least one covariate to begin.</p>")
                return()
            }
            pp <- dml_guard(dml_prepare(self$data, o$outcome, o$treat, o$covs, binary_treat = TRUE))
            if (min(sum(pp$d == 1), sum(pp$d == 0)) < 2 * o$folds) jmvcore::reject("Too few treated or control observations for this number of folds.", code = "")
            lr <- list(g = dml_learner_from_opts(o$lrn_g, o), m = dml_learner_from_opts(o$lrn_m, o))
            res <- dml_guard(dml_run("irm", pp$y, pp$d, pp$X, learners = lr, K = o$folds, n_rep = o$reps, seed = o$seed, target = o$target, trim = o$trim,
                                     checkpoint = function() private$.checkpoint()))
            notes <- sprintf("Doubly robust (AIPW) score with cross-fitted outcome regressions for the treated and the controls and a cross-fitted propensity score, trimmed to [%s, %s].",
                             dml_fmt(o$trim, 4), dml_fmt(1 - o$trim, 4))
            nt <- mean(vapply(res$reps, function(r) r$trimmed, numeric(1)))
            if (nt > 0) notes <- c(notes, sprintf("%s propensity score(s) per repetition were trimmed; with limited overlap the estimate depends on the trimming.", dml_fmt(nt, 1)))
            dml_fill(self, res, c(ate = "ATE", att = "ATT")[[o$target]], dml_learners[c(o$lrn_g, o$lrn_m)], notes, pp$n_drop, NULL)
            if (isTRUE(o$plot)) self$results$psPlot$setState(list(ps = res$reps[[1]]$propensity, d = pp$d))
        },

        .plotPs = function(image, ggtheme, theme, ...) {
            st <- image$state
            if (is.null(st)) return(FALSE)
            df <- data.frame(ps = st$ps, group = factor(ifelse(st$d == 1, "Treated", "Control"), levels = c("Control", "Treated")))
            g <- ggplot2::ggplot(df, ggplot2::aes(x = ps, fill = group)) + ggtheme +
                ggplot2::geom_histogram(position = "identity", alpha = 0.55, bins = 30, colour = NA) +
                ggplot2::scale_fill_manual(values = c(Control = "#0072B2", Treated = "#D55E00"), name = NULL) +
                ggplot2::labs(x = "Cross-fitted propensity score P(D = 1 | X)", y = "Count")
            print(g)
            TRUE
        }
    )
)
