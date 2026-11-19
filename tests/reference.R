# The engine against the R package DoubleML on the same sample splits, for PLR, PLIV, IRM (ATE and ATTE) and IIVM; DID against the IRM ATTE score on the change of the outcome.
# With OLS and logistic learners the results are deterministic, so they must agree to rounding error; with lasso
# (cross-validated penalty with its own random folds) only a loose agreement is possible.
# DoubleML and mlr3 need not be installed in the main library: set DML_REFLIB to a library that holds them.
# Run from the module root:  Rscript tests/reference.R
source("R/engine_dml.R")
lib <- Sys.getenv("DML_REFLIB"); if (nzchar(lib)) .libPaths(c(lib, .libPaths()))
nfail <- 0
chk <- function(name, got, want, tol) {
    d <- max(abs(got - want)); ok <- is.finite(d) && d < tol
    cat(sprintf("%-58s %s  max |diff| = %.1e (tol %.0e)\n", name, if (ok) "ok  " else "FAIL", d, tol)); if (!ok) nfail <<- nfail + 1
}
if (!requireNamespace("DoubleML", quietly = TRUE)) { cat("DoubleML is not available: skipped\n"); quit(status = 0) }
suppressMessages({library(DoubleML); library(mlr3); library(mlr3learners)})
lgr::get_logger("mlr3")$set_threshold("warn"); lgr::get_logger("bbotk")$set_threshold("warn")
splits <- function(folds) {
    K <- max(folds)
    list(list(train_ids = lapply(seq_len(K), function(k) which(folds != k)), test_ids = lapply(seq_len(K), function(k) which(folds == k))))
}
set.seed(11)
n <- 600; p <- 8
X <- matrix(rnorm(n * p), n, p, dimnames = list(NULL, paste0("x", 1:p)))
mu <- X[, 1] + 0.5 * X[, 2]^2 - 0.5 * X[, 3]
z <- 0.8 * X[, 1] + rnorm(n)
v <- rnorm(n)
d <- 0.6 * z + 0.5 * X[, 1] + 0.4 * X[, 4] + v
y <- 0.7 * d + mu + 0.5 * v + rnorm(n)                       # d is endogenous (shares v with y)
db <- rbinom(n, 1, plogis(0.8 * X[, 1] - 0.5 * X[, 2]))
yb <- 1.0 * db + mu + rnorm(n)
df <- data.frame(y = y, d = d, z = z, db = db, yb = yb, X)
xc <- colnames(X)
K <- 5; folds <- dml_folds(n, K); ols <- dml_learner("ols")

# ---- PLR
dat <- DoubleMLData$new(df, y_col = "y", d_cols = "d", x_cols = xc)
ref <- DoubleMLPLR$new(dat, ml_l = lrn("regr.lm"), ml_m = lrn("regr.lm"), n_folds = K, score = "partialling out", dml_procedure = "dml2")
ref$set_sample_splitting(splits(folds)); ref$fit()
me <- dml_rep_plr(y, d, X, list(l = ols, m = ols), folds)
chk("PLR, OLS learners: coefficient and standard error", c(me$theta, me$se), c(ref$coef, ref$se), 1e-9)

# ---- PLIV
dat2 <- DoubleMLData$new(df, y_col = "y", d_cols = "d", z_cols = "z", x_cols = xc)
ref2 <- DoubleMLPLIV$new(dat2, ml_l = lrn("regr.lm"), ml_m = lrn("regr.lm"), ml_r = lrn("regr.lm"), n_folds = K, score = "partialling out", dml_procedure = "dml2")
ref2$set_sample_splitting(splits(folds)); ref2$fit()
me2 <- dml_rep_pliv(y, d, z, X, list(l = ols, m = ols, r = ols), folds)
chk("PLIV, OLS learners: coefficient and standard error", c(me2$theta, me2$se), c(ref2$coef, ref2$se), 1e-9)

# ---- IRM (ATE and ATTE)
dfb <- data.frame(y = yb, d = db, X)
dat3 <- DoubleMLData$new(dfb, y_col = "y", d_cols = "d", x_cols = xc)
for (sc in c("ATE", "ATTE")) {
    ref3 <- DoubleMLIRM$new(dat3, ml_g = lrn("regr.lm"), ml_m = lrn("classif.log_reg", predict_type = "prob"), n_folds = K, score = sc, dml_procedure = "dml2", trimming_threshold = 0.01)
    ref3$set_sample_splitting(splits(folds)); suppressWarnings(ref3$fit())
    me3 <- dml_rep_irm(yb, db, X, list(g = ols, m = ols), folds, if (sc == "ATE") "ate" else "att", trim = 0.01)
    chk(sprintf("IRM %s, OLS and logit learners: coefficient and s.e.", sc), c(me3$theta, me3$se), c(ref3$coef, ref3$se), 1e-8)
}

# ---- repeated sample splitting: median aggregation
f2 <- list(dml_folds(n, K), dml_folds(n, K), dml_folds(n, K))
ref4 <- DoubleMLPLR$new(dat, ml_l = lrn("regr.lm"), ml_m = lrn("regr.lm"), n_folds = K, n_rep = 3, score = "partialling out", dml_procedure = "dml2")
ref4$set_sample_splitting(lapply(f2, function(f) splits(f)[[1]])); ref4$fit()
me4 <- dml_run("plr", y, d, X, learners = list(l = ols, m = ols), K = K, n_rep = 3, folds_list = f2)
chk("PLR, 3 repetitions: median coefficient and standard error", c(me4$theta, me4$se), c(ref4$coef, ref4$se), 1e-9)

# ---- IIVM (LATE with a binary instrument)
set.seed(21)
zb <- rbinom(n, 1, plogis(0.4 * X[, 1] - 0.3 * X[, 2]))
comp <- rbinom(n, 1, 0.55); at <- rbinom(n, 1, 0.15) * (1 - comp)                     # compliers, always-takers (the rest never take it)
dd <- ifelse(at == 1, 1, comp * zb)
yi <- 1.5 * dd + mu + rnorm(n)
dfi <- data.frame(y = yi, d = dd, z = zb, X)
dati <- DoubleMLData$new(dfi, y_col = "y", d_cols = "d", z_cols = "z", x_cols = xc)
refi <- DoubleMLIIVM$new(dati, ml_g = lrn("regr.lm"), ml_m = lrn("classif.log_reg", predict_type = "prob"), ml_r = lrn("classif.log_reg", predict_type = "prob"),
                         n_folds = K, dml_procedure = "dml2", trimming_threshold = 0.01)
refi$set_sample_splitting(splits(folds)); refi$fit()
mei <- dml_rep_iivm(yi, dd, zb, X, list(g = ols, m = ols, r = ols), folds, trim = 0.01)
chk("IIVM, OLS and logit learners: coefficient and standard error", c(mei$theta, mei$se), c(refi$coef, refi$se), 1e-8)
f3 <- list(dml_folds(n, K), dml_folds(n, K), dml_folds(n, K))
refi3 <- DoubleMLIIVM$new(dati, ml_g = lrn("regr.lm"), ml_m = lrn("classif.log_reg", predict_type = "prob"), ml_r = lrn("classif.log_reg", predict_type = "prob"),
                          n_folds = K, n_rep = 3, dml_procedure = "dml2", trimming_threshold = 0.01)
refi3$set_sample_splitting(lapply(f3, function(f) splits(f)[[1]])); refi3$fit()
mei3 <- dml_run("iivm", yi, dd, X, z = zb, learners = list(g = ols, m = ols, r = ols), K = K, n_rep = 3, folds_list = f3, trim = 0.01)
chk("IIVM, 3 repetitions: median coefficient and standard error", c(mei3$theta, mei3$se), c(refi3$coef, refi3$se), 1e-8)
cat(sprintf("%-58s %.3f (true 1.5)\n", "IIVM: estimate", mei$theta))

# ---- DID with two periods (panel): the doubly robust ATT score equals DoubleML's IRM ATTE score applied to the change of the outcome
set.seed(22)
y0 <- mu + rnorm(n); dtr <- rbinom(n, 1, plogis(0.8 * X[, 1] - 0.5 * X[, 2]))
y1 <- y0 + 0.5 + 0.3 * X[, 3] + 1.2 * dtr + rnorm(n, 0, 0.5)                             # the trend depends on X3; the effect on the treated is 1.2
dy <- y1 - y0
datd <- DoubleMLData$new(data.frame(dy = dy, d = dtr, X), y_col = "dy", d_cols = "d", x_cols = xc)
refd <- DoubleMLIRM$new(datd, ml_g = lrn("regr.lm"), ml_m = lrn("classif.log_reg", predict_type = "prob"), n_folds = K, score = "ATTE", dml_procedure = "dml2", trimming_threshold = 0.01)
refd$set_sample_splitting(splits(folds)); refd$fit()
med <- dml_rep_did(dy, dtr, X, list(g = ols, m = ols), folds, trim = 0.01)
chk("DID (panel), OLS and logit learners: equals the IRM ATTE score", c(med$theta, med$se), c(refd$coef, refd$se), 1e-8)
cat(sprintf("%-58s %.3f (true 1.2)\n", "DID: estimate", med$theta))

# ---- lasso: loose check (the penalty is chosen by cross-validation on random folds)
lasso <- dml_learner("lasso")
set.seed(5); me5 <- dml_rep_plr(y, d, X, list(l = lasso, m = lasso), folds)
chk("PLR, lasso: close to the OLS-learner estimate", me5$theta, me$theta, 0.08)
cat(if (nfail == 0) "\nAll reference checks passed.\n" else sprintf("\n%d reference check(s) FAILED.\n", nfail))
if (nfail > 0) quit(status = 1)
