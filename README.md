# dmlfamily: double machine learning for jamovi

Menu: DML

| Analysis | Model | Score |
|---|---|---|
| **Partially Linear Regression** | Y = theta D + g(X) + U, treatment continuous or binary | Partialling out (Robinson, 1988) |
| **Binary Treatment (Interactive Model)** | Heterogeneous effects of a 0/1 treatment: ATE or ATT | Doubly robust (AIPW) |
| **Partially Linear IV** | One endogenous treatment, one instrument | Partialling out for IV |
| **Binary Instrument (Interactive IV Model)** | Binary treatment, binary instrument: effect for the compliers (LATE) | Doubly robust IV score |
| **Difference-in-Differences (Panel)** | Two periods, one row per unit: effect on the treated | Doubly robust DiD score |

All five use **cross-fitting** (K folds, optionally repeated with the median over repetitions), DML2 estimation and the standard errors of Chernozhukov et al. (2018).
Learners: linear / logistic regression, lasso, ridge, elastic net (`glmnet`, penalty by cross-validation) and random forest (`ranger`).
Each nuisance function can have its own learner. The tables also show the out-of-sample RMSE and R2 of every learner and, for the binary treatment, the overlap of the propensity score.

The estimators are written in base R (`R/engine_dml.R`). With linear and logistic learners they equal the R package `DoubleML` on the same sample splits to rounding error, including ATE, ATTE, the interactive IV model (LATE) and repeated splitting (`tests/reference.R`, which needs DoubleML in a library named by `DML_REFLIB`).
With lasso and random forest the learners and their random numbers differ between packages, so estimates are close but not identical.

Example data (`data/`): `sim_plr.csv`, `sim_irm.csv`, `sim_pliv.csv` (generators in the notes of each analysis; true effects 0.5, about 1 and 0.5).

## Ribbon icon

`icon/analysis-dml.svg` (74 x 44, same size and colours as the other families): a 3 x 4 grid of folds with the held-out fold (orange) moving from round to round, an arrow to the debiased estimate with its confidence interval. jmvtools 28.17 cannot attach an icon to a module, so `dev/icon_preview.ps1` adds one CSS rule for the menu group DML to jamovi's client stylesheet (run it in an administrator PowerShell, see the comments at the top; restart jamovi afterwards).
