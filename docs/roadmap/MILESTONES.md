# MILESTONES — INSPIREI-SoundIntensityScannerAR-MATLAB

> **タスクの正本**。人間がそのまま読め、コマンドやエージェントが行頭書式をパースする。
> **書式規約（末尾）を崩さない**。運用ループは `.agents/skills/development-loop/SKILL.md`。

**状態:** フェーズ定義済み・タスク未分解（2026-07-17 に milestones.json から移行）
**採番:** `P<フェーズ>-<連番>`（backlog は `BL-<連番>`）。番号の欠番再利用は禁止。新タスクは各フェーズ末尾に連番追加

---

## P1: WAV対応 — 4ch WAVファイルからインテンシティ計算 〔未定〕
**Goal:** 4ch WAVファイルを読み込み、クロススペクトル法で音響インテンシティを計算し、3Dベクトル場として可視化できる

- [ ] **P1-1** Octave/MATLAB 両対応のテスト基盤と loadWav4ch の往復テスト ｜優先:高｜複雑度:2｜依存:-｜並行:可
  - 詳細: `tests/runAllTests.m`（`tests/test*.m` を列挙し try/catch で PASS/FAIL を集計、失敗があれば error で終了）と `tests/testLoadWav4ch.m`（tempdir に 4ch WAV を audiowrite → loadWav4ch → `[4 x N]`・fs・値の一致を確認、非4chでの error を確認、後始末）。テストは関数ファイル＋ `assert(cond, msg)` のみ
  - 受け入れ条件: `octave --no-gui --eval "addpath('tests'); runAllTests"` が終了コード0で全PASS ／ `loadWav4ch` の入出力契約（`[4 x N]`, fs）は無変更
  - 検証: 上記 Octave コマンド。MATLAB では `runAllTests` と `checkcode` を未実行として記録
  - 触るファイル: tests/runAllTests.m（新規）, tests/testLoadWav4ch.m（新規）, README.md（テスト実行手順1節）
  - 確認済み: `loadWav4ch` は audioread の正規化値（Pa換算なし）を転置して返す。`audioread/audiowrite` は Octave core。検証環境は GNU Octave 8.4.0（2026-09-27 時点、MATLAB 未導入）
- [ ] **P1-2** calcCrossSpectrum / calcIntensityPair — p-p法によるペア軸方向インテンシティ ｜優先:高｜複雑度:4｜依存:P1-1｜並行:不可
  - 詳細: `functions/acoustic/calcCrossSpectrum.m`（Welch 平均・周期 Hann 窓を自前生成・50% overlap・片側・窓パワー補正・Toolbox非依存）と `functions/acoustic/calcIntensityPair.m`（`I_r(f) = -Im{G12(f)} / (rho * 2*pi*f * micInterval)`、G12 = mean(conj(P1).*P2)、正方向 = mic1→mic2）。帯域積算値と dB（re 1e-12 W/m²、符号は別出力）を返す。式の導出元（Fahy "Sound Intensity" / ISO 9614-1）をコメントに明記
  - 受け入れ条件: `runAllTests` 全PASS（合成平面波: 有限差分補正 sin(k dr)/(k dr) 込みで理論値との相対誤差 <1%、補正なしで <5%、垂直入射で |I_r| < 1e-3×軸方向値、ch入替で符号反転、Gxx の総和 ≈ mean(x.^2) 相対誤差 <1%、Gyx == conj(Gxy)）／ professor 審査「合格」または「条件付き合格」の記録 ／ `rho`, `c`, `micInterval`, 帯域は引数（ハードコード禁止）
  - 検証: Octave で `runAllTests`。MATLAB では `cpsd(p1,p2)` との符号・スケール一致を未検証として記録。professor 招集（物理量・符号・窓・上限周波数）
  - 触るファイル: functions/acoustic/calcCrossSpectrum.m（新規）, functions/acoustic/calcIntensityPair.m（新規）, tests/testCalcCrossSpectrum.m（新規）, tests/testCalcIntensityPair.m（新規）
  - 確認済み: `functions/acoustic/` は未作成（architecture.md に予定名のみ）。Octave で `cpsd`/`hann` は signal パッケージ依存のため自前実装が必要。既存関数はいずれも `[4 x N]` 行=ch 契約
- [ ] **P1-3** calcAirProperties — 気温・気圧から rho と c を算出 ｜優先:中｜複雑度:1｜依存:P1-2｜並行:可
  - 詳細: `functions/acoustic/calcAirProperties.m`: 入力 temperature [°C], pressure [hPa] → rho = p/(R_s T)（R_s=287.05 J/(kg K), p は Pa 換算）, c = 331.3*sqrt(1+T/273.15) [m/s]。`loadSetting` の `.temperature/.pressure` をそのまま渡せる
  - 受け入れ条件: `runAllTests` 全PASS（20°C/1013.25 hPa で rho=1.204±0.005, c=343.2±0.5）／ professor 審査
  - 検証: Octave で `runAllTests`
  - 触るファイル: functions/acoustic/calcAirProperties.m（新規）, tests/testCalcAirProperties.m（新規）
  - 確認済み: Setting.txt 実物は Temperature 24.6/25 °C, Barometric Pressure 1002/1013 hPa（履歴 0a93c38）
- [ ] **P1-4** マイク幾何配置の確定と calcIntensityVector（4ch→3Dベクトル） ｜優先:高｜複雑度:4｜依存:P1-2,P1-3｜並行:不可
  - 詳細: ユーザー／Unity repo から 4ch の局所座標 `micPos [4 x 3]`（m, プローブ局所系, Unity左手系）と ch 順序を確定し `docs/decisions/decisions.md` に追記。`functions/acoustic/calcIntensityVector.m`: 全ペア (i,j) の `calcIntensityPair` 結果を単位ベクトル (r_j−r_i)/|·| と組にして最小二乗で 3D ベクトル [W/m²] を解く。プローブ姿勢でワールド系へ回転する版は P1-5 と分担
  - 受け入れ条件: 着手時に planner が定義（配置確定後）。最低限: 合成平面波の到来方向を 3 軸で復元し角度誤差 <5°／professor 審査
  - 検証: Octave で `runAllTests`
  - 触るファイル: functions/acoustic/calcIntensityVector.m（新規）, tests/testCalcIntensityVector.m（新規）, docs/decisions/decisions.md（追記）
  - 確認済み: repo・履歴にマイク配置の記録なし
  - メモ: 配置が確定するまで着手不可（ユーザー確認待ち: マイク局所座標・ch順、WAVと計測点の対応、感度校正、Sample Rate 'sixteen' の真値）
- [ ] **P1-5** WAV計測キャンペーンのプロジェクト雛形と可視化・CSV出力 ｜優先:中｜複雑度:3｜依存:P1-4｜並行:不可
  - 詳細: `projects/example_wav/`（config.m: sensitivity [Pa/FS], micPos, band, runAnalysis.m: WAV→calcIntensityVector→plotVectorField→exportCsv 'vector'）。WAV と計測点位置の対応方法はユーザー確認後に確定。exportCsv の列契約は変更しない。`Value` は dB（re 1e-12）、NormVec は正規化方向
  - 受け入れ条件: 着手時に planner が定義。最低限: 合成 WAV（tempdir 生成、data/ には置かない）で runAnalysis が Octave でエラーなし、CSV 列ヘッダが既存契約と一致
  - 検証: Octave 試走、図の目視は MATLAB 側で未検証として記録、professor 審査（Z反転・矢印の向き）
  - 触るファイル: projects/example_wav/config.m（新規）, projects/example_wav/runAnalysis.m（新規）
  - 確認済み: WAV は位置情報を内包しない。CSV 契約: `PosX,PosY,PosZ,NormVecX,NormVecY,NormVecZ,Value,IsRightHand(=1)`
- [ ] **P1-6** Unity移植メモ — 数式・単位・符号・座標系・帯域の明文化 ｜優先:中｜複雑度:2｜依存:P1-4｜並行:可
  - 詳細: `docs/specs/intensity_pp_method.md` に p-p 法の式、G12 の定義（conj(P1).*P2）、正方向、窓・overlap・nfft、rho/c 式、上限周波数の根拠、Z反転、dB 基準を Unity 側が写せる形で記載
  - 受け入れ条件: professor 合格。コードと式が一致（reviewer 確認）
  - 検証: reviewer / professor read-only
  - 触るファイル: docs/specs/intensity_pp_method.md（新規）
- [ ] **P1-7** Setting.txt の `Sample Rate : sixteen` の真値確認 ｜優先:低｜複雑度:1｜依存:-｜並行:可
  - 詳細: `loadSetting` は 'sixteen'→16 にマップ。4096 サンプル/16 Hz は物理的に不自然で 16000 Hz の可能性が高い。ユーザー確認後、loadSetting の対応表と impreza runAnalysis の注記を修正（スキーマ変更なし）
  - 受け入れ条件: 着手時に planner が定義（ユーザー回答が前提）
  - 検証: 既存 runAnalysis の試走
  - 触るファイル: functions/io/loadSetting.m, projects/2022_impreza_engine/runAnalysis.m
  - 確認済み: 履歴 0a93c38 の Setting.txt 実物に `Sample Rate : sixteen` が存在

## P2: CSV入出力 — 汎用データ連携 〔未定〕
**Goal:** 計測データをCSV（スカラー場/ベクトル場）に出力でき、CSVからの読み込みも可能

（タスク未分解。着手時に planner が起こす）

## P3: App Designer — GUIアプリ化 〔未定〕
**Goal:** App Designerアプリでフォルダ選択→データ読み込み→パラメータ設定→インテンシティ計算→3D可視化が一連の操作で完了する

（タスク未分解。着手時に planner が起こす。functions/ にUI依存コードを入れない方針は docs/architecture.md 参照）

## Backlog

（なし。寺岡さんとの結合テストは feature/teraoka-integration-test で進行中 — 設計書: docs/tasks/task_teraoka_integration_test.md。マージ時に必要なら残作業をタスク化する）

---

## 運用ルール

- **1タスク = 1ブランチ = 1エージェントセッション**
- `依存:` の全タスクが `[x]` のものだけ着手可（`依存:-` は即着手可）
- 同一ウェーブ（依存が同じ）で `並行:可` 同士かつ触るファイルが重ならなければ並行実行可
- **複雑度 5 以上は着手前に必ずサブタスク分割**
- **物理量・単位・座標系・信号処理に触るタスクは professor 審査を通過しないと完了しない**（このリポの文化）
- **タスク管理はこのファイルに一本化**（GitHub Issue は使わない）。フェーズ未定は Backlog に積み、着手時に該当フェーズへ移す

## アーカイブ（旧 `milestones.json`〔2026-07-17 廃止〕より）

- [x] **M1** 基盤: 関数分離とプロジェクト構成 — startup.m実行後、projects/2022_impreza_engine/runAnalysis.m でbytesデータの読み込み→座標変換→フィルタリング→3Dプロットが動作
- 旧 M2（WAV対応）→ **P1**、旧 M3（CSV入出力）→ **P2**、旧 M4（App Designer）→ **P3** に引き継ぎ

---

## 書式規約（機械パース用 — 崩さない）

- マイルストーン見出し: `## <ID>: <タイトル> 〔<期間>〕`、直後に `**Goal:** <1文>`
- タスク行: `- [ ] **<ID>** <タイトル> ｜優先:<最優先|高|中|低|保留>｜依存:<ID(,ID)|- >`（依存は必須。優先の省略は `中` 扱い）
  - 任意フィールド: `複雑度:<1-10>`（優先の直後）・`並行:<可|不可>`（依存の直後）
  - 優先は 最優先>高>中>低 の順に自走ループが選ぶ（同順位はファイルの出現順＝フェーズ順）。`保留` はループ対象外
  - 完了は `- [x]`。**行の削除・ID の再利用は禁止**（覆ったタスクはメモを添えて残す）
- タスク行直下のインデント箇条書きは `キー: 値` の自由フィールド:
  `詳細:` `受け入れ条件:` `検証:` `触るファイル:` `branch:` `設計書:` `確認済み:` `メモ:`
- `確認済み:` は planner が着手前に実測・確認した事実（コード実態・影響範囲・数値）。ループ中の再調査を省く根拠として残す
- `受け入れ条件:` は**検証コマンドで確認できる形**で書く（例: `checkcode` 警告0 / projects/example の試走がエラーなし / ベクトル場の向きが幾何配置と整合）。未定義なら「着手時に planner が定義」と書く


## 共通Agent環境（2026-10-01）

Harness 1.0.5を適用。見積・購入構成・設計・数値・視覚・法務財務・権限・発注本番等の重要判断は、Astra/Fable high plannerと別のsenior-reviewerで検収する。未検収・不合格・実モデル不明では判断確定・完了・ready化・mergeを保留する。通常実装と事実収集は役割別モデルを維持。

共通ソースの独立上位検収、レビューゲート64件、配布回帰29件、Codex/Claude各6役のnativeモデル確認を実施。各repoの最終対象hashと判定はPRのレビュー記録で照合する。この環境更新は製品の実機・発注・本番受入や製品開発再開の証明ではない。Harness更新後は新規セッションで開始する。
