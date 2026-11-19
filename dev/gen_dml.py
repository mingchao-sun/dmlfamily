# Generates the .a/.r/.u.yaml files of the three analyses. Run from the module root:  python dev/gen_dml.py
import os

NL = chr(10)
LEARNERS = [("ols", "Linear / logistic regression"), ("lasso", "Lasso"), ("ridge", "Ridge"), ("enet", "Elastic net (alpha 0.5)"), ("rf", "Random forest")]


def var(name, title, multi=False, perm=("numeric",), sug=None):
    s = f"    - name: {name}{NL}      title: {title}{NL}      type: {'Variables' if multi else 'Variable'}{NL}"
    if sug:
        s += f"      suggested:{NL}" + "".join(f"          - {x}{NL}" for x in sug)
    s += f"      permitted:{NL}" + "".join(f"          - {x}{NL}" for x in perm) + NL
    return s


def num(name, title, default, mn=None, mx=None, typ="Number"):
    s = f"    - name: {name}{NL}      title: {title}{NL}      type: {typ}{NL}      default: {default}{NL}"
    if mn is not None:
        s += f"      min: {mn}{NL}"
    if mx is not None:
        s += f"      max: {mx}{NL}"
    return s + NL


def lst(name, title, opts, default):
    s = f"    - name: {name}{NL}      title: {title}{NL}      type: List{NL}      options:{NL}"
    for n, t in opts:
        s += f"          - name: {n}{NL}            title: '{t}'{NL}"
    return s + f"      default: {default}{NL}{NL}"


def boo(name, title, default="false"):
    return f"    - name: {name}{NL}      title: {title}{NL}      type: Bool{NL}      default: {default}{NL}{NL}"


def head_a(name, title, mtitle, msub):
    return (f"---{NL}name: {name}{NL}title: '{title}'{NL}jas: '1.2'{NL}version: '1.0.0'{NL}menuGroup: DML{NL}"
            f"menuTitle: {mtitle}{NL}menuSubtitle: {msub}{NL}{NL}options:{NL}    - name: data{NL}      type: Data{NL}{NL}")


def common_tail():
    return (lst("rule", "Penalty chosen by cross-validation at", [("lambda.min", "The minimum error"), ("lambda.1se", "One standard error above the minimum")], "lambda.min")
            + num("folds", "Number of folds", 5, 2, 20, "Integer")
            + num("reps", "Number of repetitions of the sample split", 1, 1, 50, "Integer")
            + num("seed", "Random seed", 1234, 1, 999999, "Integer")
            + num("level", "Confidence level (%)", 95, 50, 99.9)
            + boo("showHelp", "Method notes") + boo("showGuide", "Data and setup guide") + "..." + NL)


def learner_opt(name, title, default="lasso"):
    return lst(name, title, LEARNERS, default)


def gen_a(key):
    if key == "dmlplr":
        s = head_a("dmlplr", "DML: Partially Linear Regression", "Partially Linear Regression", "Effect of a treatment with many controls")
        s += var("outcome", "Outcome") + var("treat", "Treatment (numeric)") + var("covs", "Covariates", True, ("numeric", "factor"), ("continuous", "nominal"))
        s += learner_opt("lrn_l", "Learner for the outcome, E[Y|X]") + learner_opt("lrn_m", "Learner for the treatment, E[D|X]")
    elif key == "dmlirm":
        s = head_a("dmlirm", "DML: Binary Treatment (Interactive Model)", "Binary Treatment (Interactive Model)", "ATE and ATT with doubly robust scores")
        s += var("outcome", "Outcome") + var("treat", "Treatment (0/1)", False, ("numeric", "factor")) + var("covs", "Covariates", True, ("numeric", "factor"), ("continuous", "nominal"))
        s += lst("target", "Effect", [("ate", "Average treatment effect (ATE)"), ("att", "Effect on the treated (ATT)")], "ate")
        s += learner_opt("lrn_g", "Learner for the outcome, E[Y|X,D]") + learner_opt("lrn_m", "Learner for the propensity score, P(D=1|X)")
        s += num("trim", "Trim propensity scores at", 0.01, 0.0001, 0.2) + boo("plot", "Propensity score plot", "true")
    elif key == "dmliivm":
        s = head_a("dmliivm", "DML: Binary Instrument (Interactive IV Model)", "Binary Instrument (Interactive IV)", "Effect on the compliers (LATE) with many controls")
        s += var("outcome", "Outcome") + var("treat", "Treatment (0/1)", False, ("numeric", "factor")) + var("instr", "Instrument (0/1)", False, ("numeric", "factor"))
        s += var("covs", "Covariates", True, ("numeric", "factor"), ("continuous", "nominal"))
        s += learner_opt("lrn_g", "Learner for the outcome, E[Y|X,Z]") + learner_opt("lrn_m", "Learner for the instrument, P(Z=1|X)") + learner_opt("lrn_r", "Learner for the treatment, P(D=1|X,Z)")
        s += num("trim", "Trim instrument propensity scores at", 0.01, 0.0001, 0.2) + boo("plot", "Instrument propensity score plot", "true")
    elif key == "dmldid":
        s = head_a("dmldid", "DML: Difference-in-Differences (Panel)", "Difference-in-Differences (Panel)", "Effect on the treated, two periods, many controls")
        s += var("outcome", "Outcome after the treatment") + var("before", "Outcome before the treatment") + var("treat", "Treated group (0/1)", False, ("numeric", "factor"))
        s += var("covs", "Covariates (measured before the treatment)", True, ("numeric", "factor"), ("continuous", "nominal"))
        s += learner_opt("lrn_g", "Learner for the change of the outcome of the controls") + learner_opt("lrn_m", "Learner for the propensity score, P(treated|X)")
        s += num("trim", "Trim propensity scores at", 0.01, 0.0001, 0.2) + boo("plot", "Propensity score plot", "true")
    else:
        s = head_a("dmlpliv", "DML: Partially Linear IV", "Partially Linear IV", "Instrumental variable with many controls")
        s += var("outcome", "Outcome") + var("treat", "Endogenous treatment (numeric)") + var("instr", "Instrument (numeric)")
        s += var("covs", "Covariates", True, ("numeric", "factor"), ("continuous", "nominal"))
        s += learner_opt("lrn_l", "Learner for the outcome, E[Y|X]") + learner_opt("lrn_r", "Learner for the treatment, E[D|X]") + learner_opt("lrn_m", "Learner for the instrument, E[Z|X]")
    return s + common_tail()


def gen_r(key, title):
    clear = {"dmlplr": "outcome, treat, covs, lrn_l, lrn_m", "dmlirm": "outcome, treat, covs, target, lrn_g, lrn_m, trim",
             "dmlpliv": "outcome, treat, instr, covs, lrn_l, lrn_r, lrn_m",
             "dmliivm": "outcome, treat, instr, covs, lrn_g, lrn_m, lrn_r, trim", "dmldid": "outcome, before, treat, covs, lrn_g, lrn_m, trim"}[key] + ", rule, folds, reps, seed, level"
    s = (f"---{NL}name: {key}{NL}title: '{title}'{NL}jrs: '1.1'{NL}{NL}items:{NL}"
         f"    - name: guide{NL}      title: Data and setup guide{NL}      type: Html{NL}      visible: (showGuide){NL}{NL}"
         f"    - name: helpText{NL}      title: Method notes{NL}      type: Html{NL}      visible: (showHelp){NL}{NL}"
         f"    - name: notes{NL}      title: Notes{NL}      type: Html{NL}      visible: true{NL}{NL}"
         f"    - name: est{NL}      title: 'Treatment effect'{NL}      type: Table{NL}      rows: 0{NL}      clearWith: [{clear}]{NL}      columns:{NL}"
         f"        - name: term{NL}          title: ''{NL}          type: text{NL}"
         f"        - name: coef{NL}          title: Estimate{NL}          type: number{NL}"
         f"        - name: se{NL}          title: Std. error{NL}          type: number{NL}"
         f"        - name: z{NL}          title: z{NL}          type: number{NL}"
         f"        - name: p{NL}          title: p{NL}          type: number{NL}          format: zto,pvalue{NL}"
         f"        - name: lo{NL}          title: CI lower{NL}          type: number{NL}"
         f"        - name: hi{NL}          title: CI upper{NL}          type: number{NL}{NL}"
         f"    - name: nuis{NL}      title: 'Out-of-sample accuracy of the learners'{NL}      type: Table{NL}      rows: 0{NL}      clearWith: [{clear}]{NL}      columns:{NL}"
         f"        - name: fn{NL}          title: Nuisance function{NL}          type: text{NL}"
         f"        - name: learner{NL}          title: Learner{NL}          type: text{NL}"
         f"        - name: rmse{NL}          title: RMSE{NL}          type: number{NL}"
         f"        - name: r2{NL}          title: R2{NL}          type: number{NL}{NL}"
         f"    - name: reps{NL}      title: 'Estimates by repetition of the sample split'{NL}      type: Table{NL}      rows: 0{NL}      visible: false{NL}      clearWith: [{clear}]{NL}      columns:{NL}"
         f"        - name: rep{NL}          title: Repetition{NL}          type: integer{NL}"
         f"        - name: coef{NL}          title: Estimate{NL}          type: number{NL}"
         f"        - name: se{NL}          title: Std. error{NL}          type: number{NL}{NL}")
    if key in ("dmlirm", "dmliivm", "dmldid"):
        s += (f"    - name: psPlot{NL}      title: 'Estimated propensity score by treatment'{NL}      type: Image{NL}      width: 520{NL}      height: 340{NL}"
              f"      renderFun: .plotPs{NL}      visible: (plot){NL}      clearWith: [{clear}]{NL}{NL}")
    return s + f"refs:{NL}    - chernozhukov2018{NL}    - doubleml{NL}{NL}...{NL}"


def box(label, name, single=True, height="small"):
    s = f"          - type: TargetLayoutBox{NL}            label: {label}{NL}            children:{NL}                - type: VariablesListBox{NL}                  name: {name}{NL}                  isTarget: true{NL}                  height: {height}{NL}"
    if single:
        s += f"                  maxItemCount: 1{NL}"
    return s


def gen_u(key, title):
    s = (f"title: '{title}'{NL}name: {key}{NL}jus: '3.0'{NL}stage: 0{NL}compilerMode: tame{NL}children:{NL}"
         f"    - type: VariableSupplier{NL}      persistentItems: false{NL}      stretchFactor: 1{NL}      children:{NL}")
    boxes = {"dmlplr": [("Outcome", "outcome", 1), ("Treatment (numeric)", "treat", 1), ("Covariates", "covs", 0)],
             "dmlirm": [("Outcome", "outcome", 1), ("Treatment (0/1)", "treat", 1), ("Covariates", "covs", 0)],
             "dmlpliv": [("Outcome", "outcome", 1), ("Endogenous treatment (numeric)", "treat", 1), ("Instrument (numeric)", "instr", 1), ("Covariates", "covs", 0)],
             "dmliivm": [("Outcome", "outcome", 1), ("Treatment (0/1)", "treat", 1), ("Instrument (0/1)", "instr", 1), ("Covariates", "covs", 0)],
             "dmldid": [("Outcome after the treatment", "outcome", 1), ("Outcome before the treatment", "before", 1), ("Treated group (0/1)", "treat", 1), ("Covariates (measured before the treatment)", "covs", 0)]}[key]
    for lab, nm, sg in boxes:
        s += box(lab, nm, bool(sg))
    lrn = {"dmlplr": ["lrn_l", "lrn_m"], "dmlirm": ["target", "lrn_g", "lrn_m", "trim"], "dmlpliv": ["lrn_l", "lrn_r", "lrn_m"],
           "dmliivm": ["lrn_g", "lrn_m", "lrn_r", "trim"], "dmldid": ["lrn_g", "lrn_m", "trim"]}[key]
    s += f"    - type: CollapseBox{NL}      label: Learners{NL}      collapsed: false{NL}      children:{NL}"
    for nm in lrn:
        if nm == "trim":
            s += f"          - type: TextBox{NL}            name: trim{NL}            label: Trim propensity scores at{NL}            format: number{NL}"
        else:
            s += f"          - type: ComboBox{NL}            name: {nm}{NL}"
    s += f"          - type: ComboBox{NL}            name: rule{NL}"
    s += (f"    - type: CollapseBox{NL}      label: Cross-fitting{NL}      collapsed: true{NL}      children:{NL}"
          f"          - type: TextBox{NL}            name: folds{NL}            label: Number of folds{NL}            format: number{NL}"
          f"          - type: TextBox{NL}            name: reps{NL}            label: Number of repetitions of the sample split{NL}            format: number{NL}"
          f"          - type: TextBox{NL}            name: seed{NL}            label: Random seed{NL}            format: number{NL}"
          f"          - type: TextBox{NL}            name: level{NL}            label: Confidence level (%){NL}            format: number{NL}")
    if key in ("dmlirm", "dmliivm", "dmldid"):
        s += f"          - type: CheckBox{NL}            name: plot{NL}"
    s += (f"    - type: CollapseBox{NL}      label: Output{NL}      collapsed: true{NL}      children:{NL}"
          f"          - type: CheckBox{NL}            name: showHelp{NL}            label: Method notes{NL}"
          f"          - type: CheckBox{NL}            name: showGuide{NL}            label: Data and setup guide{NL}")
    return s


TITLES = {"dmlplr": "DML: Partially Linear Regression", "dmlirm": "DML: Binary Treatment (Interactive Model)", "dmlpliv": "DML: Partially Linear IV", "dmliivm": "DML: Binary Instrument (Interactive IV Model)", "dmldid": "DML: Difference-in-Differences (Panel)"}
os.makedirs("jamovi", exist_ok=True)
for k, t in TITLES.items():
    for ext, txt in (("a", gen_a(k)), ("r", gen_r(k, t)), ("u", gen_u(k, t))):
        with open(f"jamovi/{k}.{ext}.yaml", "w", encoding="utf-8", newline="") as f:
            f.write(txt)
print("written")
