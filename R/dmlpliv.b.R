# jamovi analysis class: double machine learning, partially linear instrumental variable model.

dmlplivClass <- R6::R6Class(
    "dmlplivClass",
    inherit = dmlplivBase,
    private = list(

        .run = function() {
            o <- self$options
            dml_show_text(self$results, o, "dmlpliv")
            if (is.null(o$outcome) || is.null(o$treat) || is.null(o$instr) || length(o$covs) == 0) {
                self$results$notes$setContent("<p>Select an outcome, an endogenous treatment, an instrument and at least one covariate to begin.</p>")
                return()
            }
            pp <- dml_guard(dml_prepare(self$data, o$outcome, o$treat, o$covs, o$instr))
            lr <- list(l = dml_learner_from_opts(o$lrn_l, o), r = dml_learner_from_opts(o$lrn_r, o), m = dml_learner_from_opts(o$lrn_m, o))
            res <- dml_guard(dml_run("pliv", pp$y, pp$d, pp$X, z = pp$z, learners = lr, K = o$folds, n_rep = o$reps, seed = o$seed, checkpoint = function() private$.checkpoint()))
            notes <- "Partialling-out IV estimator with cross-fitting: the outcome, the treatment and the instrument are each predicted from the covariates, and the residual of the instrument is the instrument for the residual of the treatment."
            f <- mean(vapply(res$reps, function(r) r$first_stage_F, numeric(1)))
            notes <- c(notes, sprintf("Strength of the instrument after the covariates (first-stage F with cross-fitted residuals): %s.%s", dml_fmt(f, 1),
                                      if (f < 10) " This is below 10: the instrument is weak and the estimate and its standard error can be unreliable." else ""))
            dml_fill(self, res, "Treatment", dml_learners[c(o$lrn_l, o$lrn_r, o$lrn_m)], notes, pp$n_drop, NULL)
        }
    )
)
