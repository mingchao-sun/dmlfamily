# dmlfamily — 双重机器学习（jamovi 模块）

用双重/去偏机器学习（Chernozhukov 等，2018）估计因果效应：灵活的机器学习模型拟合干扰函数，交叉拟合，给出有效的标准误。 英文完整说明见 [README.md](README.md)。

## 分析（jamovi 菜单：DML）

| 分析 | 内容 |
|---|---|
| **部分线性回归** | Y = θD + g(X) + U，处理变量可连续或二值 |
| **二值处理（交互模型）** | 0/1 处理的 ATE 或 ATT，双重稳健得分 |
| **部分线性工具变量** | 一个内生处理变量、一个工具变量 |
| **二值工具变量（交互 IV 模型）** | 二值处理、二值工具，估计依从者的 LATE |
| **双重差分（面板）** | 两期、每个单位一行，估计处理组的处理效应 |

每个分析的输出部分都有"方法说明"和"数据与设置指南"。

学习器：线性/逻辑回归、lasso、岭、弹性网（`glmnet`）和随机森林（`ranger`），每个干扰函数可用不同学习器。结果与 R 包 `DoubleML` 在相同分折下一致到舍入误差（线性和逻辑学习器）。示例数据为模拟数据：`sim_plr.csv`、`sim_irm.csv`、`sim_pliv.csv`、`sim_iivm.csv`、`sim_did.csv`。

## 安装
- **jamovi 模块库**：在 jamovi 右上角打开模块按钮，进入 *jamovi library*，搜索并安装（模块上架后）。
- **侧载**：下载 `.jmo` 文件，在同一菜单选 *Install from file*。`.jmo` 只适用于构建它的操作系统、处理器类型和 jamovi 版本。
- **从源码**：需要 R 和 `jmvtools`：`jmvtools::install(home = "C:/Program Files/jamovi 28.17.0.0")`（路径按本机 jamovi 修改）。

## 引用与许可
引用：Sun, M. *dmlfamily* (jamovi module). https://github.com/mingchao-sun/dmlfamily 。请同时引用所用方法的原始文献（输出中列出）。

许可：见 `DESCRIPTION`（GPL）；第三方代码与数据见 `NOTICE`。问题与建议：https://github.com/mingchao-sun/dmlfamily/issues

日本語の要約:[README.ja.md](README.ja.md)
