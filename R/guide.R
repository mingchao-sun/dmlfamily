# "Data and setup guide" and "Method notes" for each analysis.

dml_settings <- function(rows) {
    paste0("<table style='border-collapse:collapse;margin:4px 0 8px 0'>",
           "<tr><th style='text-align:left;padding:2px 14px 2px 0;border-bottom:1px solid #999'>Field</th>",
           "<th style='text-align:left;padding:2px 0;border-bottom:1px solid #999'>Set to</th></tr>",
           paste0("<tr><td style='padding:2px 14px 2px 0'>", names(rows), "</td><td style='padding:2px 0'>",
                  unlist(rows), "</td></tr>", collapse = ""), "</table>")
}

dml_common_opts <- paste0(
    "<h4>Options</h4><ul>",
    "<li><b>Learners</b>: the machine-learning method that predicts each nuisance function from the covariates. Linear/logistic regression is the baseline; lasso, ridge and elastic net handle many covariates; the random forest captures non-linearities and interactions.</li>",
    "<li><b>Penalty chosen at</b>: for lasso, ridge and elastic net, the cross-validated penalty at the minimum error (default) or one standard error above it (sparser).</li>",
    "<li><b>Number of folds</b>: the sample is split in K parts; each part is predicted by a model fitted on the others (cross-fitting). 5 is usual.</li>",
    "<li><b>Number of repetitions</b>: repeating the random split and taking the median makes the result less dependent on one split; more than one repetition also shows the spread.</li>",
    "<li><b>Random seed</b>: fixes the split so that results can be reproduced.</li></ul>")

dml_guide_raw <- function(key) {
    switch(key,
    dmlplr = paste0(
        "<h3>Partially Linear Regression: data and setup</h3>",
        "<p>Estimates the effect of a treatment on an outcome when many covariates must be controlled for, with machine learning for the controls (double/debiased machine learning, Chernozhukov et al., 2018). The model is Y = theta D + g(X) + U with a flexible g.</p>",
        "<h4>Sample data</h4>",
        dml_settings(list("Dataset" = "<b>Simulated partially linear model</b>", "Outcome" = "y", "Treatment" = "d", "Covariates" = "x1 to x20",
                          "Learners" = "Lasso for both", "Folds, repetitions, seed" = "5, 1, 1234")),
        "<p>1,000 rows, 20 correlated covariates, non-linear dependence on x1 and x3; the true effect is 0.5. Expected: theta = 0.497 (s.e. 0.034). With linear regression 0.497 (0.034), ridge 0.499 (0.034), random forest 0.518 (0.033). ",
        "Out-of-sample R2 of the lasso: 0.37 for the outcome and 0.52 for the treatment.</p>",
        "<h4>Data layout</h4><p>One row per observation. The outcome and the treatment are numeric (the treatment may be binary 0/1 or continuous); a nominal treatment with two values is read with the second as 1. Covariates may be numeric or nominal (nominal variables become dummies). Rows with missing values are dropped and counted.</p>",
        dml_common_opts),
    dmlirm = paste0(
        "<h3>Binary Treatment (Interactive Model): data and setup</h3>",
        "<p>Average effect of a binary treatment with many covariates, allowing the effect to differ across units: a doubly robust (AIPW) estimator in which the outcome regressions and the propensity score are learned by machine learning with cross-fitting.</p>",
        "<h4>Sample data</h4>",
        dml_settings(list("Dataset" = "<b>Simulated binary treatment</b>", "Outcome" = "y", "Treatment (0/1)" = "d", "Covariates" = "x1 to x10",
                          "Effect" = "ATE or ATT", "Learners" = "Lasso for both", "Folds, repetitions, seed" = "5, 1, 1234")),
        "<p>2,000 rows, treatment depends on x1, x2 and x3*x4, heterogeneous effect (sample ATE 0.979, ATT 1.107). Expected with lasso: ATE 0.996 (s.e. 0.062), ATT 1.186 (0.071); random forest: ATE 1.066 (0.060), ATT 1.233 (0.064); linear and logistic regression: ATE 0.992 (0.066), ATT 1.153 (0.078).</p>",
        "<h4>Data layout</h4><p>One row per observation. The treatment is 0/1 (or a nominal variable with two values, the second being treated). Enough treated and control units are needed in every fold. Propensity scores are trimmed at the chosen value; the plot shows the overlap.</p>",
        dml_common_opts),
    dmlpliv = paste0(
        "<h3>Partially Linear IV: data and setup</h3>",
        "<p>Effect of an endogenous treatment using an instrument, with many covariates and machine learning for the controls.</p>",
        "<h4>Sample data</h4>",
        dml_settings(list("Dataset" = "<b>Simulated partially linear IV</b>", "Outcome" = "y", "Endogenous treatment" = "d", "Instrument" = "z", "Covariates" = "x1 to x10",
                          "Learners" = "Random forest for all three", "Folds, repetitions, seed" = "5, 1, 1234")),
        "<p>1,000 rows; the treatment shares an unobserved term with the outcome, so OLS is biased; the true effect is 0.5. Expected with the random forest: theta = 0.473 (s.e. 0.046), first-stage F about 704. With the lasso or linear regression the estimate is 0.40 (0.048) because they miss the quadratic term in x2.</p>",
        "<h4>Data layout</h4><p>One row per observation; outcome, treatment and instrument numeric; one instrument and one treatment. Covariates numeric or nominal.</p>",
        dml_common_opts),
    dmliivm = paste0(
        "<h3>Binary Instrument (Interactive IV Model): data and setup</h3>",
        "<p>Effect of a binary treatment on the units whose treatment is changed by a binary instrument (the compliers, the local average treatment effect), with many covariates and machine learning for the nuisance functions: the doubly robust IV score of the interactive IV model (Chernozhukov et al., 2018).</p>",
        "<h4>Sample data</h4>",
        dml_settings(list("Dataset" = "<b>Simulated binary instrument</b>", "Outcome" = "y", "Treatment (0/1)" = "d", "Instrument (0/1)" = "z", "Covariates" = "x1 to x10",
                          "Learners" = "Lasso for all three", "Folds, repetitions, seed" = "5, 1, 1234")),
        "<p>2,000 rows; z is an encouragement that raises take-up d for 55% of the units (compliers), 15% always take up and 30% never do. The effect for the compliers is 1.0 + 0.3 x3 (sample LATE 0.991). Expected: LATE 1.009 (s.e. 0.101, interval 0.812 to 1.206), estimated share of compliers 54.9%; accuracy table with R2 0.36 for E[Y|X,Z], 0.30 for E[D|X,Z] and 0.05 for the instrument. With linear and logistic regression 0.996 (0.102), random forest 1.180 (0.095).</p>",
        "<h4>Data layout</h4><p>One row per observation. The treatment and the instrument are 0/1 (or nominal with two values, the second being 1); the instrument must raise the treatment (monotonicity). The instrument is assumed to be as good as random given the covariates and to affect the outcome only through the treatment.</p>",
        dml_common_opts),
    dmldid = paste0(
        "<h3>Difference-in-Differences (Panel): data and setup</h3>",
        "<p>Effect of a treatment on the treated when the same units are observed before and after it, with a treated and a control group: the change of the outcome is compared between the groups, controlling flexibly for covariates that drive both selection into treatment and the trend (doubly robust difference-in-differences of Sant'Anna and Zhao, 2020, with cross-fitting).</p>",
        "<h4>Sample data</h4>",
        dml_settings(list("Dataset" = "<b>Simulated panel difference-in-differences</b>", "Outcome after the treatment" = "y_after", "Outcome before the treatment" = "y_before", "Treated group (0/1)" = "treated",
                          "Covariates" = "x1 to x6", "Learners" = "Lasso for both", "Folds, repetitions, seed" = "5, 1, 1234")),
        "<p>2,000 units in wide format (one row per unit). The trend depends on x1 and x4 and the probability of treatment on x1 and x2, so the plain difference in changes (1.235) is biased; the effect on the treated is 1.0 + 0.3 x3 (sample ATT 1.009). Expected: ATT 1.045 (s.e. 0.040, interval 0.967 to 1.123) against the plain difference in changes 1.235. With linear and logistic regression 1.050 (0.040), random forest 1.072 (0.043).</p>",
        "<h4>Data layout</h4><p>One row per unit with the outcome in two separate columns (before and after) and a 0/1 treated-group indicator. Covariates must be measured before the treatment. Repeated cross-sections (different units in each period) and more than two periods are not handled here: for several periods and staggered adoption use the Difference-in-Differences family.</p>",
        dml_common_opts),
    stop("unknown guide: ", key))
}

dml_notes_raw <- function(key) {
    common <- paste0(
        "<h4>How cross-fitting works</h4><p>Machine-learning predictions are biased by regularisation and overfit the sample they are trained on. ",
        "Double machine learning removes the effect of both: the estimating equation is orthogonal (insensitive to small errors in the predictions), and every prediction is made by a model that did not see that observation (cross-fitting). ",
        "The estimate is then asymptotically normal even with many covariates, and the standard errors are the usual sandwich ones.</p>",
        "<h4>Limits</h4><p>The method removes bias from flexible control for the observed covariates; it does not solve confounding by unobserved variables. ",
        "Results vary with the sample split (use repetitions) and with the learners; check that conclusions do not hinge on one learner. ",
        "Results equal the R package DoubleML on the same splits (OLS and logistic learners); with lasso and random forest the learners and their random numbers differ between packages, so estimates are close but not identical. ",
        "Stata ddml gives the same ATE and ATT; for the partially linear models its second step has a constant and a degrees-of-freedom correction, which changes the estimate by about 0.00002 and the standard error by 0.1%.</p>")
    switch(key,
    dmlplr = paste0("<h3>Partially Linear Regression: method notes</h3>",
        "<h4>What it does</h4><p>Partialling out (Robinson, 1988): predict the outcome Y and the treatment D from the covariates X by machine learning, take the residuals, and regress the outcome residual on the treatment residual. ",
        "With DML2 the coefficient is the sum of the products of residuals over the sum of squared treatment residuals, pooled over all folds.</p>",
        "<h4>How to read the results</h4><ul><li><b>Estimate and standard error</b>: the effect of a one-unit change of the treatment.</li>",
        "<li><b>Accuracy of the learners</b>: out-of-sample RMSE and R2 of each prediction. If the treatment is almost unpredictable from X (R2 near 0), there is little confounding to remove.</li></ul>", common),
    dmlirm = paste0("<h3>Binary Treatment (Interactive Model): method notes</h3>",
        "<h4>What it does</h4><p>Estimates the average treatment effect (ATE) or the effect on the treated (ATT) with the doubly robust score: outcome regressions for treated and control units, g1(X) and g0(X), and the propensity score m(X), all learned with cross-fitting. ",
        "The estimate stays consistent if either the outcome regressions or the propensity score is well estimated, and is robust to the errors in both.</p>",
        "<h4>How to read the results</h4><ul><li>The propensity score plot should show both groups spread over the same range; scores near 0 or 1 mean units without comparable counterparts. Scores outside the trimming bounds are set to the bound.</li>",
        "<li>ATT needs only the control outcome regression and compares treated units with reweighted controls.</li></ul>", common),
    dmlpliv = paste0("<h3>Partially Linear IV: method notes</h3>",
        "<h4>What it does</h4><p>Partialling out for IV: predict the outcome, the treatment and the instrument from the covariates; the residual of the instrument is the instrument for the residual of the treatment. ",
        "The coefficient is the ratio of the sums of products of residuals: instrument with outcome over instrument with treatment.</p>",
        "<h4>How to read the results</h4><ul><li>The first-stage F with cross-fitted residuals measures the strength of the instrument given the covariates; a value below 10 warns of a weak instrument.</li>",
        "<li>The instrument must be valid (exogenous and excluded); the method does not test this.</li></ul>", common),
    dmliivm = paste0("<h3>Binary Instrument (Interactive IV Model): method notes</h3>",
        "<h4>What it does</h4><p>Estimates the effect for the compliers with the score psi = [g1(X) - g0(X) + Z (Y - g1)/m(X) - (1 - Z)(Y - g0)/(1 - m(X))] - theta [r1(X) - r0(X) + Z (D - r1)/m(X) - (1 - Z)(D - r0)/(1 - m(X))], where g_z(X) is the outcome regression and r_z(X) the treatment regression in instrument group z and m(X) = P(Z = 1 | X). ",
        "The numerator is the effect of the instrument on the outcome, the denominator its effect on the treatment, both estimated with doubly robust scores; their ratio is the local average treatment effect.</p>",
        "<h4>How to read the results</h4><ul><li>The share of compliers (in the notes) is the denominator: if it is close to zero the instrument is weak and the estimate unstable.</li>",
        "<li>The instrument propensity plot shows the overlap of the two instrument groups; scores outside the trimming bounds are set to the bound.</li>",
        "<li>Validity (random given X, exclusion, monotonicity) is assumed, not tested.</li></ul>", common),
    dmldid = paste0("<h3>Difference-in-Differences (Panel): method notes</h3>",
        "<h4>What it does</h4><p>The treated group would have followed the trend of the controls with the same covariates (conditional parallel trends). The effect on the treated is estimated with the doubly robust score (D/p - (1 - D) m(X)/(p (1 - m(X)))) (Y_after - Y_before - g0(X)), where g0(X) is the expected change among the controls and m(X) the propensity of being treated, both learned with cross-fitting; the estimate is consistent if either is right. ",
        "It equals the effect on the treated of the Binary Treatment analysis applied to the change of the outcome.</p>",
        "<h4>How to read the results</h4><ul><li>Compare with the plain difference in changes (in the notes): a big difference means the covariates matter for the trend.</li>",
        "<li>The propensity score plot should show overlap; units with scores near 1 have no comparable controls.</li>",
        "<li>Parallel trends cannot be tested with two periods; check with earlier periods in the Difference-in-Differences family.</li></ul>", common),
    stop("unknown notes: ", key))
}

dml_guide_html <- function(key) dml_guide_raw(key)
dml_notes_html <- function(key) dml_notes_raw(key)
