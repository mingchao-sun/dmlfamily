# Bias and coverage of the IIVM and DID estimators in simulated data (OLS and logit learners, so that it runs quickly). Run from the module root:  Rscript tests/properties.R
source("R/engine_dml.R")
nfail <- 0
ok <- function(cond, msg) { cat(sprintf("[%s] %s\n", if (isTRUE(cond)) "PASS" else "FAIL", msg)); if (!isTRUE(cond)) nfail <<- nfail + 1 }
ols <- dml_learner("ols")
nrep <- 150; n <- 1200
iivm <- replicate(nrep, {
    X <- matrix(rnorm(n * 3), n, 3); z <- rbinom(n, 1, plogis(0.4 * X[, 1])); comp <- rbinom(n, 1, 0.5); d <- comp * z
    y <- 1.5 * d + X[, 1] + 0.5 * X[, 2] + rnorm(n) + 0.5 * (1 - comp)                  # compliers gain 1.5; the type also shifts the outcome
    r <- dml_rep_iivm(y, d, z, X, list(g = ols, m = ols, r = ols), dml_folds(n, 5)); c(r$theta, r$se)
})
cov_i <- mean(abs(iivm[1, ] - 1.5) < 1.96 * iivm[2, ])
ok(abs(mean(iivm[1, ]) - 1.5) < 0.05, sprintf("IIVM: average estimate %.3f, true LATE 1.5", mean(iivm[1, ])))
ok(cov_i > 0.89 && cov_i < 0.99, sprintf("IIVM: 95%% intervals cover the LATE in %.0f%% of %d samples", 100 * cov_i, nrep))
did <- replicate(nrep, {
    X <- matrix(rnorm(n * 3), n, 3); d <- rbinom(n, 1, plogis(0.8 * X[, 1] - 0.5 * X[, 2]))
    dy <- 0.5 + 0.3 * X[, 3] + 0.4 * X[, 1] + 1.2 * d + rnorm(n, 0, 0.7)                  # trend depends on covariates that also drive selection into treatment
    r <- dml_rep_did(dy, d, X, list(g = ols, m = ols), dml_folds(n, 5)); c(r$theta, r$se)
})
cov_d <- mean(abs(did[1, ] - 1.2) < 1.96 * did[2, ])
ok(abs(mean(did[1, ]) - 1.2) < 0.05, sprintf("DID: average estimate %.3f, true effect on the treated 1.2", mean(did[1, ])))
ok(cov_d > 0.89 && cov_d < 0.99, sprintf("DID: 95%% intervals cover the effect in %.0f%% of %d samples", 100 * cov_d, nrep))
naive <- replicate(60, { X <- matrix(rnorm(n * 3), n, 3); d <- rbinom(n, 1, plogis(0.8 * X[, 1] - 0.5 * X[, 2])); dy <- 0.5 + 0.4 * X[, 1] + 1.2 * d + rnorm(n, 0, 0.7)
                         mean(dy[d == 1]) - mean(dy[d == 0]) })
ok(abs(mean(naive) - 1.2) > 0.1, sprintf("the plain difference in changes is biased here (%.2f), so the covariate adjustment matters", mean(naive)))
cat(if (nfail == 0) "\nAll property checks passed.\n" else sprintf("\n%d check(s) FAILED.\n", nfail))
if (nfail > 0) quit(status = 1)
