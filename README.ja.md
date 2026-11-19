# dmlfamily — 二重機械学習（jamovi モジュール）

二重/脱バイアス機械学習（Chernozhukov ら, 2018）による因果効果の推定。ニュイサンス関数を柔軟な学習器で推定し、クロスフィッティングで妥当な標準誤差を得ます。 詳しい英語の説明は [README.md](README.md)、中国語の要約は [README.zh.md](README.zh.md) を参照してください。

## 分析（jamovi メニュー：DML）

| 分析 | 内容 |
|---|---|
| **部分線形回帰** | Y = θD + g(X) + U。処置は連続でも 2 値でも可 |
| **2 値処置（交互作用モデル）** | 0/1 処置の ATE または ATT。二重頑健スコア |
| **部分線形操作変数** | 内生的な処置 1 つと操作変数 1 つ |
| **2 値操作変数（交互作用 IV モデル）** | 2 値処置と 2 値操作変数。コンプライアーの LATE |
| **差の差（パネル）** | 2 期、1 単位 1 行。処置群の効果 |

各分析の出力には「方法の説明」と「データと設定ガイド」があります。

学習器：線形/ロジスティック回帰、lasso、リッジ、弾性ネット（`glmnet`）、ランダムフォレスト（`ranger`）。線形・ロジスティック学習器では、同じ分割で R パッケージ `DoubleML` と丸め誤差の範囲で一致します。サンプルデータ（シミュレーション）：`sim_plr.csv`、`sim_irm.csv`、`sim_pliv.csv`、`sim_iivm.csv`、`sim_did.csv`。

## インストール
- **jamovi ライブラリ**：jamovi 右上のモジュールボタンから *jamovi library* を開き、検索してインストール（モジュール公開後）。
- **サイドロード**：`.jmo` ファイルをダウンロードし、同じメニューの *Install from file* から導入します。`.jmo` はビルドした OS、プロセッサ、jamovi のバージョンでのみ動作します。
- **ソースから**：R と `jmvtools` が必要です：`jmvtools::install(home = "C:/Program Files/jamovi 28.17.0.0")`（パスはお使いの jamovi に合わせてください）。

## 引用とライセンス
引用：Sun, M. *dmlfamily* (jamovi module). https://github.com/mingchao-sun/dmlfamily 。使用した手法の原論文（出力に記載）も併せて引用してください。

ライセンス：`DESCRIPTION` を参照（GPL）。第三者のコードとデータは `NOTICE` に記載。不具合や提案：https://github.com/mingchao-sun/dmlfamily/issues
