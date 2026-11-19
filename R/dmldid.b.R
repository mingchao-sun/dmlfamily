# jamovi analysis class: double machine learning difference-in-differences with two periods (panel data): effect on the treated.

dmldidClass <- R6::R6Class(
    "dmldidClass",
    inherit = dmldidBase,
    private = list(

        .run = function() {
            o <- self$options
            dml_show_text(self$results, o, "dmldid")
            if (is.null(o$outcome) || is.null(o$before) || is.null(o$treat) || length(o$covs) == 0) {
                self$results$notes$setContent("<p>Select the outcome after and before the treatment, the treated group indicator and at least one covariate to begin. The data have one row per unit.</p>")
                return()
            }
            if (identical(o$outcome, o$before)) jmvcore::reject("The outcome after and before the treatment must be different variables.", code = "")
            dat <- self$data
            num <- function(v, label) { if (is.factor(v)) jmvcore::reject(sprintf("The %s must be a numeric variable (set its type to Continuous in the Data tab).", label), code = ""); as.numeric(v) }
            dat[[".change"]] <- num(dat[[o$outcome]], "outcome after the treatment") - num(dat[[o$before]], "outcome before the treatment")
            pp <- dml_guard(dml_prepare(dat, ".change", o$treat, o$covs, binary_treat = TRUE))
            if (min(sum(pp$d == 1), sum(pp$d == 0)) < 2 * o$folds) jmvcore::reject("Too few treated or control units for this number of folds.", code = "")
            lr <- list(g = dml_learner_from_opts(o$lrn_g, o), m = dml_learner_from_opts(o$lrn_m, o))
            res <- dml_guard(dml_run("did", pp$y, pp$d, pp$X, learners = lr, K = o$folds, n_rep = o$reps, seed = o$seed, trim = o$trim, checkpoint = function() private$.checkpoint()))
            notes <- sprintf("Effect on the treated (ATT) of the change of the outcome: doubly robust score of Sant'Anna and Zhao (2020) with a cross-fitted regression of the change on the covariates among the controls and a cross-fitted propensity score, trimmed to [%s, %s]. The plain difference in changes is %s.",
                             dml_fmt(o$trim, 4), dml_fmt(1 - o$trim, 4), dml_fmt(mean(pp$y[pp$d == 1]) - mean(pp$y[pp$d == 0]), 3))
            nt <- mean(vapply(res$reps, function(r) r$trimmed, numeric(1)))
            if (nt > 0) notes <- c(notes, sprintf("%s propensity score(s) per repetition were trimmed; with limited overlap the estimate depends on the trimming.", dml_fmt(nt, 1)))
            dml_fill(self, res, "ATT", dml_learners[c(o$lrn_g, o$lrn_m)], notes, pp$n_drop, NULL)
            if (isTRUE(o$plot)) self$results$psPlot$setState(list(ps = res$reps[[1]]$propensity, d = pp$d, label = "Cross-fitted propensity score P(treated | X)", groups = c("Control", "Treated")))
        },

        .plotPs = function(image, ggtheme, theme, ...) {
            st <- image$state
            if (is.null(st)) return(FALSE)
            df <- data.frame(ps = st$ps, group = factor(ifelse(st$d == 1, st$groups[2], st$groups[1]), levels = st$groups))
            g <- ggplot2::ggplot(df, ggplot2::aes(x = ps, fill = group)) + ggtheme +
                ggplot2::geom_histogram(position = "identity", alpha = 0.55, bins = 30, colour = NA) +
                ggplot2::scale_fill_manual(values = stats::setNames(c("#0072B2", "#D55E00"), st$groups), name = NULL) +
                ggplot2::labs(x = st$label, y = "Count")
            print(g)
            TRUE
        }
    )
)
