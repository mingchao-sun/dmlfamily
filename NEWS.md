# dmlfamily 1.0.0

* First public release (jamovi library submission). Contains everything listed below; the earlier 0.x entries are development history.

# dmlfamily 0.2.0

* New: **Binary Instrument (Interactive IV Model)**: the effect for the compliers (LATE) of a binary treatment with a binary instrument, doubly robust score, cross-fitting; equals DoubleML's IIVM on the same splits (also with repeated splitting).
* New: **Difference-in-Differences (Panel)**: the effect on the treated with two periods and one row per unit, doubly robust score of Sant'Anna and Zhao with cross-fitting; equals DoubleML's IRM ATTE score applied to the change of the outcome.

# dmlfamily 0.1.0

First version. Three analyses in the menu group DML:

* **Partially Linear Regression**, **Binary Treatment (Interactive Model)** (ATE and ATT) and **Partially Linear IV**, with cross-fitting, repeated sample splitting (median aggregation) and per-function learners: linear/logistic, lasso, ridge, elastic net and random forest.
* Out-of-sample RMSE and R2 of every learner; propensity score plot and trimming for the binary treatment; first-stage F for the IV model.

Results equal the R package DoubleML on the same sample splits for the linear and logistic learners. Method notes and a data and setup guide are in the Output section of each analysis.
