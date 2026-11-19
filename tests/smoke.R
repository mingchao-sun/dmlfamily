# Headless run of the three analyses (the .b.R classes) on the sample data and on edge cases.
# Run from the module root, best in jamovi's own R with the jamovi libraries:  Rscript tests/smoke.R
suppressMessages({library(jmvcore); library(R6); library(ggplot2)})
for (f in c("R/00jmv.R", "R/common.R", "R/engine_dml.R", "R/guide.R", list.files("R", "[.]h[.]R$", full.names = TRUE), list.files("R", "[.]b[.]R$", full.names = TRUE))) source(f)
plr <- read.csv("data/sim_plr.csv"); irm <- read.csv("data/sim_irm.csv"); pliv <- read.csv("data/sim_pliv.csv")
bad <- 0
run <- function(label, fn, data, expect_error = FALSE, ...) {
    a <- list(...)
    fm <- formals(fn)
    for (n in setdiff(names(fm)[vapply(fm, function(z) identical(z, quote(expr = )), logical(1))], c("data", names(a)))) a[n] <- list(NULL)
    t0 <- Sys.time()
    r <- tryCatch({ res <- do.call(fn, c(list(data = data), a)); invisible(capture.output(print(res))); "ok" }, error = function(e) paste("ERROR:", conditionMessage(e)))
    good <- if (expect_error) grepl("^ERROR", r) else r == "ok"
    cat(sprintf("%-50s %5.1fs  %s\n", label, as.numeric(difftime(Sys.time(), t0, units = "secs")), if (good) substr(r, 1, 80) else paste("UNEXPECTED:", r))); if (!good) bad <<- bad + 1
    invisible(NULL)
}
xs <- paste0("x", 1:20)
for (l in c("ols", "lasso", "ridge", "enet", "rf")) run(paste("PLR", l), dmlplr, plr, outcome = "y", treat = "d", covs = xs, lrn_l = l, lrn_m = l)
run("PLR lambda.1se, 3 repetitions, 3 folds", dmlplr, plr, outcome = "y", treat = "d", covs = xs, rule = "lambda.1se", reps = 3, folds = 3)
run("PLR notes and guide", dmlplr, plr, outcome = "y", treat = "d", covs = xs, showGuide = TRUE, showHelp = TRUE)
x10 <- paste0("x", 1:10)
for (tg in c("ate", "att")) run(paste("IRM", tg, "lasso"), dmlirm, irm, outcome = "y", treat = "d", covs = x10, target = tg)
run("IRM random forest + plot", dmlirm, irm, outcome = "y", treat = "d", covs = x10, lrn_g = "rf", lrn_m = "rf")
run("IRM linear, 2 repetitions", dmlirm, irm, outcome = "y", treat = "d", covs = x10, lrn_g = "ols", lrn_m = "ols", reps = 2)
for (l in c("ols", "lasso", "rf")) run(paste("PLIV", l), dmlpliv, pliv, outcome = "y", treat = "d", instr = "z", covs = x10, lrn_l = l, lrn_r = l, lrn_m = l)
iv <- read.csv("data/sim_iivm.csv"); did <- read.csv("data/sim_did.csv"); x6 <- paste0("x", 1:6)
for (l in c("ols", "lasso", "rf")) run(paste("IIVM", l), dmliivm, iv, outcome = "y", treat = "d", instr = "z", covs = x10, lrn_g = l, lrn_m = l, lrn_r = l)
run("IIVM 2 repetitions, 3 folds, no plot, notes and guide", dmliivm, iv, outcome = "y", treat = "d", instr = "z", covs = x10, reps = 2, folds = 3, plot = FALSE, showGuide = TRUE, showHelp = TRUE)
run("IIVM nominal instrument", dmliivm, transform(iv, z = factor(ifelse(z == 1, "yes", "no"))), outcome = "y", treat = "d", instr = "z", covs = x10)
run("IIVM instrument not binary (error)", dmliivm, transform(iv, z = z * 2), TRUE, outcome = "y", treat = "d", instr = "z", covs = x10)
run("IIVM instrument lowers the treatment (error)", dmliivm, transform(iv, z = 1 - z), TRUE, outcome = "y", treat = "d", instr = "z", covs = x10)
run("IIVM no instrument (hint)", dmliivm, iv, outcome = "y", treat = "d", instr = NULL, covs = x10)
for (l in c("ols", "lasso", "rf")) run(paste("DID", l), dmldid, did, outcome = "y_after", before = "y_before", treat = "treated", covs = x6, lrn_g = l, lrn_m = l)
run("DID 2 repetitions, notes and guide", dmldid, did, outcome = "y_after", before = "y_before", treat = "treated", covs = x6, reps = 2, showGuide = TRUE, showHelp = TRUE)
run("DID same outcome twice (error)", dmldid, did, TRUE, outcome = "y_after", before = "y_after", treat = "treated", covs = x6)
run("DID treated group not 0/1 (error)", dmldid, transform(did, treated = treated * 3), TRUE, outcome = "y_after", before = "y_before", treat = "treated", covs = x6)
run("DID no before outcome (hint)", dmldid, did, outcome = "y_after", before = NULL, treat = "treated", covs = x6)
# edge cases
run("no covariates (hint only)", dmlplr, plr, outcome = "y", treat = "d", covs = NULL)
run("missing outcome selection (hint only)", dmlplr, plr, outcome = NULL, treat = "d", covs = xs)
d2 <- plr; d2$y[1:20] <- NA
run("missing values are dropped", dmlplr, d2, outcome = "y", treat = "d", covs = xs)
d3 <- irm; d3$d <- d3$d * 2
run("IRM treatment not 0/1", dmlirm, d3, TRUE, outcome = "y", treat = "d", covs = x10)
d4 <- irm[1:30, ]
run("too few rows", dmlplr, d4, TRUE, outcome = "y", treat = "d", covs = x10)
d5 <- plr; d5$x1 <- factor(sample(letters[1:3], nrow(d5), TRUE))
run("nominal covariate", dmlplr, d5, outcome = "y", treat = "d", covs = xs)
d6 <- plr; d6$x2 <- d6$x1
run("collinear covariates", dmlplr, d6, outcome = "y", treat = "d", covs = xs)
d7 <- plr; d7$d <- 1
run("constant treatment", dmlplr, d7, TRUE, outcome = "y", treat = "d", covs = xs)
cat(if (bad == 0) "\nAll checks passed.\n" else sprintf("\n%d check(s) failed.\n", bad))
if (bad > 0) quit(status = 1)
