# Sample data of the interactive IV model and of the panel DID. Run from the module root:  Rscript dev/make_data_iv_did.R
set.seed(20261118)
# ---- binary instrument: an encouragement (z) raises take-up of a programme (d); compliers gain 1.0 on average (LATE), always-takers gain differently
n <- 2000; p <- 10
X <- matrix(round(rnorm(n * p), 3), n, p, dimnames = list(NULL, paste0("x", 1:p)))
z <- rbinom(n, 1, plogis(0.4 * X[, 1] - 0.3 * X[, 2]))
type <- sample(c("complier", "always", "never"), n, TRUE, c(0.55, 0.15, 0.30))
d <- ifelse(type == "always", 1, ifelse(type == "complier", z, 0))
tau <- ifelse(type == "complier", 1.0 + 0.3 * X[, 3], 0.4)
y <- round(0.8 * X[, 1] + 0.5 * X[, 2]^2 - 0.4 * X[, 4] + 0.6 * (type == "always") + d * tau + rnorm(n), 3)
iivm <- data.frame(y = y, d = d, z = z, X)
write.csv(iivm, "data/sim_iivm.csv", row.names = FALSE)
cat("complier share", round(mean(type == "complier"), 3), " LATE in the sample", round(mean(tau[type == "complier"]), 3), "\n")
# ---- panel difference-in-differences: two periods, one row per unit; selection into treatment and the trend depend on covariates; the effect on the treated is 1.0 + 0.3 x3
set.seed(20261119)
n <- 2000; p <- 6
X <- matrix(round(rnorm(n * p), 3), n, p, dimnames = list(NULL, paste0("x", 1:p)))
treated <- rbinom(n, 1, plogis(-0.3 + 0.8 * X[, 1] - 0.5 * X[, 2]))
alpha <- rnorm(n, 0, 1) + 0.5 * X[, 1]
trend <- 0.5 + 0.4 * X[, 1] + 0.3 * X[, 4]
eff <- 1.0 + 0.3 * X[, 3]
y_before <- round(alpha + X[, 2] + rnorm(n, 0, 0.5), 3)
y_after <- round(alpha + X[, 2] + trend + treated * eff + rnorm(n, 0, 0.5), 3)
did <- data.frame(unit = seq_len(n), treated = treated, y_before = y_before, y_after = y_after, X)
write.csv(did, "data/sim_did.csv", row.names = FALSE)
cat("effect on the treated in the sample", round(mean(eff[treated == 1]), 3), " share treated", round(mean(treated), 3),
    " plain difference in changes", round(mean((y_after - y_before)[treated == 1]) - mean((y_after - y_before)[treated == 0]), 3), "\n")
