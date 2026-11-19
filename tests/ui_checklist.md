# dmlfamily: checklist for testing in jamovi

Menu: DML. Install: `jmvtools::install(home = "C:/Program Files/jamovi 28.17.0.0")`.
Open sample data from File > Open > Data Library > Double Machine Learning Family. Seed 1234, 5 folds, 1 repetition are the defaults; with these, the numbers below must appear exactly.

## 1. Partially Linear Regression
Dataset: Simulated partially linear model. Outcome `y`; Treatment `d`; Covariates `x1` to `x20` (drag all 20); Learners: Lasso and Lasso.
Expect: estimate 0.497 (s.e. 0.034); accuracy table with R2 about 0.37 for E[Y|X] and 0.52 for E[D|X]; the note says "1000 observations; 5-fold cross-fitting, 1 repetition".
Then: switch both learners to Linear (0.497), Ridge (0.499), Random forest (0.518, s.e. 0.033; takes a few seconds); try different learners for the two functions.
Then: Number of repetitions 5 -> a table of estimates by repetition appears and the note says median; Number of folds 3; Penalty at "One standard error above the minimum"; Random seed 1 -> a different estimate; confidence level 90.

## 2. Binary Treatment (Interactive Model)
Dataset: Simulated binary treatment. Outcome `y`; Treatment `d`; Covariates `x1` to `x10`; Effect ATE; Lasso and Lasso.
Expect: ATE 0.996 (s.e. 0.062); change Effect to ATT: 1.186 (0.071); linear learners: ATE 0.992 (0.066), ATT 1.153 (0.078); random forest: ATE 1.066, ATT 1.233.
The propensity score plot shows two overlapping histograms (control blue, treated orange); the note counts trimmed scores. Change "Trim propensity scores at" to 0.1: the note reports trimmed scores and the estimate moves a little. Untick the plot: it disappears.
Messages: put a variable with values 0/1/2 as treatment -> "must be binary".

## 3. Partially Linear IV
Dataset: Simulated partially linear IV. Outcome `y`; Endogenous treatment `d`; Instrument `z`; Covariates `x1` to `x10`; Random forest for all three.
Expect: estimate 0.473 (s.e. 0.046); note with first-stage F about 704. With Lasso or Linear learners: 0.404 (0.048), F about 571.

## 4. Binary Instrument (Interactive IV Model)
Dataset: Simulated binary instrument. Outcome `y`; Treatment `d`; Instrument `z`; Covariates `x1` to `x10`; Lasso for all three.
Expect: LATE 1.009 (s.e. 0.101, interval 0.812 to 1.206); the note gives the share of compliers 54.9%; accuracy table with three rows (R2 0.36, 0.30, 0.05). Linear/logistic for all three: 0.996 (0.102); random forest: 1.180 (0.095). Plot of the instrument propensity score by instrument group.
Messages: instrument with values 0/2 -> "must be binary"; an instrument that lowers take-up (recode 1 - z) -> message about the direction; no instrument -> hint.

## 5. Difference-in-Differences (Panel)
Dataset: Simulated panel difference-in-differences. Outcome after `y_after`; Outcome before `y_before`; Treated group `treated`; Covariates `x1` to `x6`; Lasso for both.
Expect: ATT 1.045 (s.e. 0.040, interval 0.967 to 1.123); the note shows the plain difference in changes 1.235. Linear/logistic: 1.050 (0.040); random forest: 1.072 (0.043).
Messages: the same variable as before and after -> message; treated group not 0/1 -> "must be binary".

## Things to look at in the interface
- Tables fill in as variables are dropped into the boxes and clear when a variable is removed; with no covariates a plain message asks for one.
- A covariate cannot also be the outcome, treatment or instrument (message in plain words); a variable can sit in one box only.
- A nominal covariate expands into dummies; a covariate with missing values: rows are dropped and counted in the note.
- Computing time: random forest with 5 repetitions on 1,000 rows should stay within a minute; the analysis can be interrupted by changing an option.
- Method notes and Data and setup guide (headed sections, sample values match the screen).
- Number formats, the propensity plot with the dark theme and another jamovi palette, long variable names.
- The ribbon shows the DML group (the icon needs `dev/icon_preview.ps1`).
