# dmlfamily — double machine learning in jamovi

A jamovi module for causal effects estimated with double/debiased machine learning (Chernozhukov et al., 2018): flexible
learners for the nuisance functions, cross-fitting, and valid standard errors for the effect. Chinese summary: [README.zh.md](README.zh.md). Japanese summary: [README.ja.md](README.ja.md).

## Analyses (jamovi menu: DML)

| Analysis | Model | Score |
|---|---|---|
| **Partially Linear Regression** | Y = theta D + g(X) + U, treatment continuous or binary | Partialling out (Robinson, 1988) |
| **Binary Treatment (Interactive Model)** | Heterogeneous effects of a 0/1 treatment: ATE or ATT | Doubly robust (AIPW) |
| **Partially Linear IV** | One endogenous treatment, one instrument | Partialling out for IV |
| **Binary Instrument (Interactive IV Model)** | Binary treatment, binary instrument: effect for the compliers (LATE) | Doubly robust IV score |
| **Difference-in-Differences (Panel)** | Two periods, one row per unit: effect on the treated | Doubly robust DiD score |

All five use **cross-fitting** (K folds, optionally repeated with the median over repetitions), DML2 estimation and the standard errors of
Chernozhukov et al. (2018). Learners: linear / logistic regression, lasso, ridge, elastic net (`glmnet`, penalty by cross-validation) and random
forest (`ranger`); each nuisance function can have its own learner. The tables also show the out-of-sample RMSE and R2 of every learner and, for
the binary treatment, the overlap of the propensity score. Every analysis has *Method notes* and *Data and setup guide* in its Output section.

## Install
- **jamovi library**: in jamovi open the modules button (top right), *jamovi library*, find *Double Machine Learning Family* and install (once the module is listed).
- **Sideload**: download the `.jmo` file and use *Install from file* in the same menu. A `.jmo` works only on the operating system, processor type and jamovi version it was built for.
- **From source** (needs R and the jamovi compiler `jmvtools`; adjust the path to your jamovi folder):
```r
jmvtools::install(home = "C:/Program Files/jamovi 28.17.0.0")
```

## Use from R (Rj editor, scripts)
Every analysis is also an R function, for example
```r
dmlfamily::dmlplr(data = d, outcome = "y", treat = "d", covs = paste0("x", 1:20), lrn_l = "lasso", lrn_m = "lasso")
```

## Data format
One row per observation (one row per unit with the outcome in both periods for the panel DiD). Outcome and covariates numeric; the binary treatment
and binary instrument coded 0/1. Rows with missing values are dropped and reported.

## Example data
Shown in jamovi under **Open > Data Library > Double Machine Learning Family**; each entry says which analysis to use and which variable goes where.
Files in `data/` (generators are described in the notes of each analysis):

| File | Design | True effect |
|---|---|---|
| `sim_plr.csv` | Partially linear model, 20 correlated covariates, non-linear nuisance functions | 0.5 |
| `sim_irm.csv` | Binary treatment with confounding and heterogeneous effects | about 1 |
| `sim_pliv.csv` | Endogenous treatment and one instrument | 0.5 |
| `sim_iivm.csv` | Binary treatment (take-up) and binary instrument (encouragement) | LATE for the compliers |
| `sim_did.csv` | Two-period panel, wide format | effect on the treated |

## References
Papers and R packages behind each analysis appear in the References section of the jamovi output (defined in `jamovi/00refs.yaml`).

## Validation
The estimators are written in base R (`R/engine_dml.R`). `tests/reference.R` compares them with the R package `DoubleML` on the same sample splits:
with linear and logistic learners the estimates and standard errors agree to rounding error for the partially linear model, the interactive model
(ATE and ATTE), partially linear IV, the interactive IV model (LATE) and repeated splitting. The panel DiD equals the ATTE score of `DoubleML` applied to
the change in the outcome (`DoubleML` has no DiD class for two periods). `tests/properties.R` checks bias and coverage in simulations. `tests/smoke.R`
runs every analysis headless, including bad input. With lasso and random forest the learners and their random numbers differ between packages, so
estimates are close but not identical.

## Known limitations
- One endogenous treatment and one instrument; no multiple-treatment or high-dimensional-instrument models.
- The panel DiD analysis handles two periods with a fixed treated group (no staggered adoption); use `didfamily` for staggered designs.
- Estimates depend on the random sample split: the seed option makes them reproducible, and repeating the split (median over repetitions) makes them stable.
- Propensity scores near 0 or 1 inflate the variance of the binary-treatment, IV and DiD estimators; the tables show the overlap and the propensity score can be trimmed.

## Notes for developers
- Layout: `R/engine_dml.R` is plain R with no jamovi dependency; `R/*.b.R` and `jamovi/*.yaml` are the jamovi front end. Analysis definitions are partly generated by scripts in `dev/`.
- Tests: `Rscript tests/smoke.R`, `tests/reference.R` (needs `DoubleML`, in a library named by `DML_REFLIB`), `tests/properties.R`; `tests/ui_checklist.md` lists what to check by hand in jamovi.
- Ribbon icon: `icon/analysis-dml.svg` (74 x 44), a grid of folds with the held-out fold moving from round to round. jmvtools 28.17 cannot attach an icon to a module, so `dev/icon_preview.ps1` adds one CSS rule for the menu group to jamovi's client stylesheet (administrator PowerShell, restart jamovi afterwards).

## How to cite
Sun, M. *dmlfamily: Double Machine Learning Family for jamovi* (jamovi module). https://github.com/mingchao-sun/dmlfamily. Please also cite Chernozhukov et al. (2018) and the papers behind the analysis you use.

## License
GPL-3, as stated in `DESCRIPTION`; third-party code and data are listed in `NOTICE.md`. Bug reports and suggestions: https://github.com/mingchao-sun/dmlfamily/issues
