# Helpers shared by the DML analyses.

dml_fmt <- function(x, d = 3) formatC(x, format = "f", digits = d, drop0trailing = TRUE)

dml_guard <- function(expr) tryCatch(expr, error = function(e) jmvcore::reject(conditionMessage(e), code = ""))

dml_show_text <- function(results, opts, key) {
    if (isTRUE(opts$showGuide)) results$guide$setContent(dml_guide_html(key))
    if (isTRUE(opts$showHelp)) results$helpText$setContent(dml_notes_html(key))
}

# Outcome, treatment, optional instrument and covariates from the jamovi data frame. Rows with a missing value are dropped.
dml_prepare <- function(data, outcome, treat, covs, instr = NULL, binary_treat = FALSE) {
    if (length(covs) == 0) stop("Select at least one covariate.", call. = FALSE)
    both <- intersect(covs, c(outcome, treat, instr))
    if (length(both)) stop("A variable cannot be a covariate and also the outcome, the treatment or the instrument.", call. = FALSE)
    vars <- unique(c(outcome, treat, instr, covs))
    df <- data[, vars, drop = FALSE]
    keep <- stats::complete.cases(df)
    n_drop <- sum(!keep); df <- df[keep, , drop = FALSE]
    if (nrow(df) < 40) stop("Fewer than 40 complete observations.", call. = FALSE)
    num <- function(v, label) {
        if (is.factor(v)) stop(sprintf("The %s must be a numeric variable (set its type to Continuous in the Data tab).", label), call. = FALSE)
        x <- as.numeric(v)
        if (any(!is.finite(x))) stop(sprintf("The %s has infinite values.", label), call. = FALSE)
        x
    }
    y <- num(df[[outcome]], "outcome")
    tv <- df[[treat]]
    d <- if (is.factor(tv)) {
        lv <- levels(droplevels(tv))
        if (length(lv) != 2) stop("A nominal treatment must have exactly two levels (the second level is treated).", call. = FALSE)
        as.numeric(droplevels(tv) == lv[2])
    } else num(tv, "treatment")
    if (binary_treat && !all(d %in% c(0, 1))) stop("The treatment must be binary (0/1).", call. = FALSE)
    if (stats::sd(y) == 0) stop("The outcome has no variation.", call. = FALSE)
    if (stats::sd(d) == 0) stop("The treatment has no variation.", call. = FALSE)
    z <- if (!is.null(instr)) num(df[[instr]], "instrument") else NULL
    if (!is.null(z) && stats::sd(z) == 0) stop("The instrument has no variation.", call. = FALSE)
    for (v in covs) if (is.factor(df[[v]])) df[[v]] <- droplevels(df[[v]]) else df[[v]] <- num(df[[v]], paste("covariate", v))
    mm <- stats::model.matrix(stats::reformulate(paste0("`", covs, "`")), df)
    X <- mm[, -1, drop = FALSE]
    X <- X[, apply(X, 2, stats::sd) > 0, drop = FALSE]
    if (ncol(X) == 0) stop("The covariates have no variation.", call. = FALSE)
    list(y = y, d = d, z = z, X = X, n = length(y), n_drop = n_drop)
}

dml_learner_from_opts <- function(type, o) dml_learner(type, lambda_rule = o$rule)

# Fills the result tables common to the three analyses.
dml_fill <- function(self, res, term, learner_rows, notes, n_drop, learner_names) {
    o <- self$options
    alpha <- 1 - o$level / 100
    crit <- stats::qnorm(1 - alpha / 2)
    et <- self$results$est
    z <- res$theta / res$se
    et$addRow(rowKey = 1, values = list(term = term, coef = res$theta, se = res$se, z = z, p = 2 * stats::pnorm(-abs(z)),
                                        lo = res$theta - crit * res$se, hi = res$theta + crit * res$se))
    et$setNote("n", sprintf("%d observations; %d-fold cross-fitting, %d repetition%s of the sample split%s.", res$n, res$K, res$n_rep, if (res$n_rep > 1) "s" else "",
                            if (res$n_rep > 1) " (median estimate)" else ""))
    nt <- self$results$nuis
    for (i in seq_len(nrow(res$diag)))
        nt$addRow(rowKey = i, values = list(fn = rownames(res$diag)[i], learner = learner_rows[i], rmse = res$diag[i, "rmse"], r2 = res$diag[i, "r2"]))
    nt$setNote("a", "Cross-fitted predictions: every observation is predicted by a model fitted on the other folds. A low R2 for the treatment or instrument equation means little of it is explained by the covariates.")
    if (res$n_rep > 1) {
        rt <- self$results$reps
        rt$setVisible(TRUE)
        for (r in seq_len(res$n_rep)) rt$addRow(rowKey = r, values = list(rep = r, coef = res$reps[[r]]$theta, se = res$reps[[r]]$se))
        rt$setNote("a", "The reported estimate is the median over repetitions; its standard error adds the spread across repetitions (Chernozhukov et al., 2018).")
    }
    if (n_drop > 0) notes <- c(notes, sprintf("%d observation(s) with missing values were dropped.", n_drop))
    self$results$notes$setContent(if (length(notes)) paste0("<p>", paste(notes, collapse = " "), "</p>") else "")
}
