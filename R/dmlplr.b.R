# jamovi analysis class: double machine learning, partially linear regression.

dmlplrClass <- R6::R6Class(
    "dmlplrClass",
    inherit = dmlplrBase,
    private = list(

        .run = function() {
            o <- self$options
            dml_show_text(self$results, o, "dmlplr")
            if (is.null(o$outcome) || is.null(o$treat) || length(o$covs) == 0) {
                self$results$notes$setContent("<p>Select an outcome, a treatment and at least one covariate to begin.</p>")
                return()
            }
            pp <- dml_guard(dml_prepare(self$data, o$outcome, o$treat, o$covs))
            lr <- list(l = dml_learner_from_opts(o$lrn_l, o), m = dml_learner_from_opts(o$lrn_m, o))
            res <- dml_guard(dml_run("plr", pp$y, pp$d, pp$X, learners = lr, K = o$folds, n_rep = o$reps, seed = o$seed, checkpoint = function() private$.checkpoint()))
            dml_fill(self, res, "Treatment", dml_learners[c(o$lrn_l, o$lrn_m)], c(
                "Partialling-out estimator (Robinson, 1988) with cross-fitting: the outcome and the treatment are each predicted from the covariates, and the residuals of the treatment explain the residuals of the outcome."),
                pp$n_drop, NULL)
        }
    )
)
