# Double/debiased machine learning (Chernozhukov et al., 2018, Econometrics Journal) with cross-fitting.
# Partially linear regression, interactive regression model (binary treatment) and partially linear IV.
# Learners: OLS/logit, lasso, ridge, elastic net (glmnet) and random forest (ranger, optional).
# Checked against the R package DoubleML (same sample splits). Scores and variances follow DoubleML's
# "partialling out" (PLR, PLIV) and ATE/ATTE (IRM) scores with the DML2 estimator.

dml_learners <- c(ols = "Linear / logistic regression", lasso = "Lasso", ridge = "Ridge", enet = "Elastic net (alpha 0.5)",
                  rf = "Random forest")

# A learner is a function(Xtr, ytr, Xte, binary) returning predictions for Xte: the conditional mean, or the
# probability when binary = TRUE. X is a numeric matrix without intercept.
dml_learner <- function(type, lambda_rule = "lambda.min", nfolds_cv = 5, trees = 500) {
    force(type); force(lambda_rule); force(nfolds_cv); force(trees)
    function(Xtr, ytr, Xte, binary = FALSE) {
        if (type == "ols") {
            if (!binary) {
                fit <- stats::lm.fit(cbind(1, Xtr), ytr)
                b <- fit$coefficients; b[is.na(b)] <- 0
                return(as.numeric(cbind(1, Xte) %*% b))
            }
            fit <- suppressWarnings(stats::glm.fit(cbind(1, Xtr), ytr, family = stats::binomial()))
            b <- fit$coefficients; b[is.na(b)] <- 0
            return(as.numeric(stats::plogis(cbind(1, Xte) %*% b)))
        }
        if (type %in% c("lasso", "ridge", "enet")) {
            alpha <- switch(type, lasso = 1, ridge = 0, enet = 0.5)
            if (ncol(Xtr) < 2) {                                   # glmnet needs at least two columns
                Xtr <- cbind(Xtr, 0); Xte <- cbind(Xte, 0)
            }
            cv <- glmnet::cv.glmnet(Xtr, ytr, alpha = alpha, nfolds = nfolds_cv, family = if (binary) "binomial" else "gaussian")
            return(as.numeric(stats::predict(cv, Xte, s = lambda_rule, type = "response")))
        }
        if (type == "rf") {
            if (!requireNamespace("ranger", quietly = TRUE)) stop("The random forest needs the ranger package.", call. = FALSE)
            if (binary) {
                fit <- ranger::ranger(x = Xtr, y = factor(ytr, levels = c(0, 1)), num.trees = trees, probability = TRUE)
                return(as.numeric(stats::predict(fit, Xte)$predictions[, "1"]))
            }
            fit <- ranger::ranger(x = Xtr, y = ytr, num.trees = trees)
            return(as.numeric(stats::predict(fit, Xte)$predictions))
        }
        stop("Unknown learner.", call. = FALSE)
    }
}

# Balanced random assignment of observations to K folds.
dml_folds <- function(n, K) sample(rep(seq_len(K), length.out = n))

# Out-of-sample predictions: every observation is predicted by a model fitted on the other folds.
# idx (optional): fit only on these training rows (for the outcome regressions by treatment status).
dml_crossfit <- function(learner, X, y, folds, binary = FALSE, subset = NULL) {
    K <- max(folds); out <- numeric(length(y))
    for (k in seq_len(K)) {
        te <- folds == k
        tr <- !te
        if (!is.null(subset)) tr <- tr & subset
        if (sum(tr) < 5) stop("Too few observations in a training sample; use fewer folds.", call. = FALSE)
        out[te] <- learner(X[tr, , drop = FALSE], y[tr], X[te, , drop = FALSE], binary)
    }
    out
}

dml_r2 <- function(y, yhat) 1 - sum((y - yhat)^2) / sum((y - mean(y))^2)

# One repetition. Returns the estimate, the standard error, the score and diagnostics of the nuisance predictions.
dml_rep_plr <- function(y, d, X, learners, folds) {
    lh <- dml_crossfit(learners$l, X, y, folds); mh <- dml_crossfit(learners$m, X, d, folds)
    u <- y - lh; v <- d - mh
    th <- sum(v * u) / sum(v^2)
    psi <- (u - th * v) * v
    J <- mean(v^2)
    se <- sqrt(mean(psi^2) / J^2 / length(y))
    list(theta = th, se = se, psi = psi / J, diag = rbind(`E[Y|X]` = c(sqrt(mean(u^2)), dml_r2(y, lh)), `E[D|X]` = c(sqrt(mean(v^2)), dml_r2(d, mh))))
}

dml_rep_pliv <- function(y, d, z, X, learners, folds) {
    lh <- dml_crossfit(learners$l, X, y, folds); rh <- dml_crossfit(learners$r, X, d, folds); mh <- dml_crossfit(learners$m, X, z, folds)
    u <- y - lh; w <- d - rh; v <- z - mh
    den <- sum(w * v)
    if (abs(den) < 1e-12) stop("The instrument has no partial relation with the treatment after the controls.", call. = FALSE)
    th <- sum(u * v) / den
    psi <- (u - th * w) * v
    J <- mean(w * v)
    se <- sqrt(mean(psi^2) / J^2 / length(y))
    list(theta = th, se = se, psi = psi / J, diag = rbind(`E[Y|X]` = c(sqrt(mean(u^2)), dml_r2(y, lh)), `E[D|X]` = c(sqrt(mean(w^2)), dml_r2(d, rh)),
                                                         `E[Z|X]` = c(sqrt(mean(v^2)), dml_r2(z, mh))),
         first_stage_F = (sum(w * v)^2 / sum(v^2)) / (sum((w - (sum(w * v) / sum(v^2)) * v)^2) / (length(y) - 1)))
}

dml_rep_irm <- function(y, d, X, learners, folds, target = c("ate", "att"), trim = 0.01) {
    target <- match.arg(target)
    g0 <- dml_crossfit(learners$g, X, y, folds, subset = d == 0)
    g1 <- dml_crossfit(learners$g, X, y, folds, subset = d == 1)
    mh <- dml_crossfit(learners$m, X, d, folds, binary = TRUE)
    mc <- pmin(pmax(mh, trim), 1 - trim)
    n <- length(y)
    if (target == "ate") {
        psi_b <- g1 - g0 + d * (y - g1) / mc - (1 - d) * (y - g0) / (1 - mc)
        th <- mean(psi_b)
        psi <- psi_b - th
        se <- sqrt(mean(psi^2) / n)
        sc <- psi
    } else {
        p <- numeric(n)                                        # share treated in the fold, as DoubleML
        for (k in seq_len(max(folds))) p[folds == k] <- mean(d[folds == k])
        psi_b <- d * (y - g0) / p - mc * (1 - d) * (y - g0) / (p * (1 - mc))
        psi_a <- -d / p
        th <- -sum(psi_b) / sum(psi_a)
        psi <- psi_b + psi_a * th
        J <- mean(psi_a)
        se <- sqrt(mean(psi^2) / J^2 / n)
        sc <- psi / J
    }
    yfit <- ifelse(d == 1, g1, g0)
    list(theta = th, se = se, psi = sc, trimmed = sum(mh < trim | mh > 1 - trim),
         diag = rbind(`E[Y|X,D]` = c(sqrt(mean((y - yfit)^2)), dml_r2(y, yfit)), `P(D=1|X)` = c(sqrt(mean((d - mh)^2)), dml_r2(d, mh))),
         propensity = mh)
}

# Interactive IV model (binary treatment D, binary instrument Z): local average treatment effect for the compliers, DoubleML's LATE score
# with subgroups always-takers and never-takers (E[D|X,Z=z] estimated in each instrument group). DML2 estimator.
dml_rep_iivm <- function(y, d, z, X, learners, folds, trim = 0.01) {
    g0 <- dml_crossfit(learners$g, X, y, folds, subset = z == 0)
    g1 <- dml_crossfit(learners$g, X, y, folds, subset = z == 1)
    mh <- dml_crossfit(learners$m, X, z, folds, binary = TRUE)
    r0 <- dml_crossfit(learners$r, X, d, folds, binary = TRUE, subset = z == 0)
    r1 <- dml_crossfit(learners$r, X, d, folds, binary = TRUE, subset = z == 1)
    mc <- pmin(pmax(mh, trim), 1 - trim)
    n <- length(y)
    psi_b <- g1 - g0 + z * (y - g1) / mc - (1 - z) * (y - g0) / (1 - mc)
    psi_a <- -(r1 - r0 + z * (d - r1) / mc - (1 - z) * (d - r0) / (1 - mc))
    th <- -sum(psi_b) / sum(psi_a)
    psi <- psi_b + psi_a * th
    J <- mean(psi_a)
    se <- sqrt(mean(psi^2) / J^2 / n)
    yfit <- ifelse(z == 1, g1, g0); dfit <- ifelse(z == 1, r1, r0)
    list(theta = th, se = se, psi = psi / J, trimmed = sum(mh < trim | mh > 1 - trim), compliers = -J,
         diag = rbind(`E[Y|X,Z]` = c(sqrt(mean((y - yfit)^2)), dml_r2(y, yfit)), `E[D|X,Z]` = c(sqrt(mean((d - dfit)^2)), dml_r2(d, dfit)), `P(Z=1|X)` = c(sqrt(mean((z - mh)^2)), dml_r2(z, mh))),
         propensity = mh)
}

# Difference-in-differences with two periods and panel data (one row per unit): the effect on the treated, ATT, with the doubly robust score of
# Sant'Anna and Zhao (2020) and cross-fitted nuisance functions. dy is the change of the outcome, d = 1 for the treated group, X pre-treatment covariates.
# Score: psi_b = (d / p - (1 - d) m / (p (1 - m))) (dy - g0(X)), psi_a = -d / p, with p the share treated in the fold (as in dml_rep_irm).
dml_rep_did <- function(dy, d, X, learners, folds, trim = 0.01) {
    g0 <- dml_crossfit(learners$g, X, dy, folds, subset = d == 0)
    mh <- dml_crossfit(learners$m, X, d, folds, binary = TRUE)
    mc <- pmin(pmax(mh, trim), 1 - trim)
    n <- length(dy)
    p <- numeric(n); for (k in seq_len(max(folds))) p[folds == k] <- mean(d[folds == k])
    psi_b <- d * (dy - g0) / p - mc * (1 - d) * (dy - g0) / (p * (1 - mc))
    psi_a <- -d / p
    th <- -sum(psi_b) / sum(psi_a)
    psi <- psi_b + psi_a * th
    J <- mean(psi_a)
    se <- sqrt(mean(psi^2) / J^2 / n)
    list(theta = th, se = se, psi = psi / J, trimmed = sum(mh < trim | mh > 1 - trim),
         diag = rbind(`E[change|X,D=0]` = c(sqrt(mean((dy - g0)[d == 0]^2)), dml_r2(dy[d == 0], g0[d == 0])), `P(D=1|X)` = c(sqrt(mean((d - mh)^2)), dml_r2(d, mh))),
         propensity = mh)
}

# Repeated sample splitting: median over repetitions; the variance is aggregated as in Chernozhukov et al. (2018, Def. 3.3),
# sigma^2 = median(sigma_r^2 + (theta_r - theta)^2) for the asymptotic variance sigma^2 = n se^2, as DoubleML does.
dml_aggregate <- function(reps, n) {
    th <- vapply(reps, `[[`, numeric(1), "theta"); se <- vapply(reps, `[[`, numeric(1), "se")
    if (length(reps) == 1) return(list(theta = th, se = se))
    t0 <- stats::median(th)
    list(theta = t0, se = sqrt(stats::median(n * se^2 + (th - t0)^2) / n))
}

# Run the chosen model. model: "plr", "pliv", "irm", "iivm" or "did" (for "did" y holds the change of the outcome). Restores the caller's random-number state.
dml_run <- function(model, y, d, X, z = NULL, learners, K = 5, n_rep = 1, seed = 1234, target = "ate", trim = 0.01, folds_list = NULL, checkpoint = NULL) {
    old <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv()) else NULL
    on.exit(if (!is.null(old)) assign(".Random.seed", old, envir = globalenv()), add = TRUE)
    set.seed(seed)
    n <- length(y)
    if (n < 4 * K) stop("Too few observations for this number of folds.", call. = FALSE)
    reps <- vector("list", n_rep)
    for (r in seq_len(n_rep)) {
        if (!is.null(checkpoint)) checkpoint()
        folds <- if (!is.null(folds_list)) folds_list[[r]] else dml_folds(n, K)
        reps[[r]] <- switch(model,
            plr = dml_rep_plr(y, d, X, learners, folds),
            pliv = dml_rep_pliv(y, d, z, X, learners, folds),
            irm = dml_rep_irm(y, d, X, learners, folds, target, trim),
            iivm = dml_rep_iivm(y, d, z, X, learners, folds, trim),
            did = dml_rep_did(y, d, X, learners, folds, trim),
            stop("Unknown model.", call. = FALSE))
    }
    ag <- dml_aggregate(reps, n)
    dg <- Reduce(`+`, lapply(reps, `[[`, "diag")) / n_rep
    colnames(dg) <- c("rmse", "r2")
    list(theta = ag$theta, se = ag$se, reps = reps, diag = dg, n = n, K = K, n_rep = n_rep,
         thetas = vapply(reps, `[[`, numeric(1), "theta"))
}
