# jamovi analysis class: double machine learning, interactive IV model (binary treatment, binary instrument): LATE for the compliers.

dmliivmClass <- R6::R6Class(
    "dmliivmClass",
    inherit = dmliivmBase,
    private = list(

        .run = function() {
            o <- self$options
            dml_show_text(self$results, o, "dmliivm")
            if (is.null(o$outcome) || is.null(o$treat) || is.null(o$instr) || length(o$covs) == 0) {
                self$results$notes$setContent("<p>Select an outcome, a binary treatment, a binary instrument and at least one covariate to begin.</p>")
                return()
            }
            dat <- self$data
            if (is.factor(dat[[o$instr]])) {
                lv <- levels(droplevels(dat[[o$instr]]))
                if (length(lv) != 2) jmvcore::reject("A nominal instrument must have exactly two levels (the second level is 1).", code = "")
                dat[[o$instr]] <- as.numeric(droplevels(dat[[o$instr]]) == lv[2])
            }
            pp <- dml_guard(dml_prepare(dat, o$outcome, o$treat, o$covs, instr = o$instr, binary_treat = TRUE))
            if (!all(pp$z %in% c(0, 1))) jmvcore::reject("The instrument must be binary (0/1).", code = "")
            if (min(sum(pp$z == 1), sum(pp$z == 0)) < 2 * o$folds) jmvcore::reject("Too few units in an instrument group for this number of folds.", code = "")
            if (stats::cor(pp$d, pp$z) <= 0) jmvcore::reject("The instrument must raise the treatment (a positive relation between the instrument and the treatment); recode the instrument if it lowers it.", code = "")
            lr <- list(g = dml_learner_from_opts(o$lrn_g, o), m = dml_learner_from_opts(o$lrn_m, o), r = dml_learner_from_opts(o$lrn_r, o))
            res <- dml_guard(dml_run("iivm", pp$y, pp$d, pp$X, z = pp$z, learners = lr, K = o$folds, n_rep = o$reps, seed = o$seed, trim = o$trim,
                                     checkpoint = function() private$.checkpoint()))
            notes <- sprintf("Effect on the compliers (units whose treatment is changed by the instrument): doubly robust score with cross-fitted outcome regressions and treatment regressions in each instrument group and a cross-fitted instrument propensity score, trimmed to [%s, %s]. The estimated share of compliers is %s%%.",
                             dml_fmt(o$trim, 4), dml_fmt(1 - o$trim, 4), dml_fmt(100 * mean(vapply(res$reps, function(r) r$compliers, numeric(1))), 1))
            nt <- mean(vapply(res$reps, function(r) r$trimmed, numeric(1)))
            if (nt > 0) notes <- c(notes, sprintf("%s instrument propensity score(s) per repetition were trimmed.", dml_fmt(nt, 1)))
            dml_fill(self, res, "LATE (compliers)", dml_learners[c(o$lrn_g, o$lrn_r, o$lrn_m)], notes, pp$n_drop, NULL)
            if (isTRUE(o$plot)) self$results$psPlot$setState(list(ps = res$reps[[1]]$propensity, d = pp$z, label = "Cross-fitted instrument propensity score P(Z = 1 | X)", groups = c("Z = 0", "Z = 1")))
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
