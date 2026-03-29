# Architecture

## 構成
共通関数（functions/）と計測キャンペーン固有スクリプト（projects/）を分離したスクリプトベース構成。
各プロジェクトがdata/, config.m, runAnalysis.mを自己完結で持つ。
将来的にApp Designerでアプリ化する際も、functions/の関数群をそのまま呼び出す設計。

## ディレクトリ構成
```
SISAR/
├── startup.m                    # パス設定（MATLABで最初に実行）
├── functions/
│   ├── io/                      # データ読み書き
│   │   ├── loadBytes.m          # .bytes一括読み込み → 構造体配列
│   │   ├── loadSetting.m        # Setting.txt読み込み → 構造体
│   │   ├── loadWav4ch.m         # 4ch WAV読み込み → [4 x N]
│   │   ├── exportCsv.m          # CSV出力（scalar/vector）
│   │   └── exportBytes.m        # .bytes出力（インデックス振り直し対応）
│   ├── transform/               # 座標変換・フィルタ
│   │   ├── applyTranslation.m   # 平行移動
│   │   ├── applyRotation.m      # オイラー角ベースの回転
│   │   ├── eulerToQuat.m        # オイラー角→クォータニオン変換
│   │   └── filterPoints.m       # 条件関数でフィルタリング
│   ├── acoustic/                # 音響計算（今後追加）
│   │   ├── calcIntensity.m
│   │   ├── calcCrossSpectrum.m
│   │   └── calcSoundPressure.m
│   └── vis/                     # 可視化
│       ├── plotScatter3d.m      # 3Dスキャッタープロット
│       ├── plotVectorField.m    # ベクトル場表示
│       └── plotIntensityMap.m   # インテンシティカラーマップ
├── projects/                    # 計測キャンペーンごとの解析
│   ├── example/                 # 使い方サンプル
│   │   ├── data/                # サンプルデータ
│   │   ├── config.m
│   │   └── runAnalysis.m
│   ├── 2022_impreza_engine/
│   │   ├── data/                # この計測のデータ（.gitignore）
│   │   ├── config.m             # パラメータ設定
│   │   └── runAnalysis.m        # 解析実行スクリプト
│   └── 2022_speaker_honjo/
│       ├── data/
│       ├── config.m
│       └── runAnalysis.m
├── archives/                    # 旧コード保管（.gitignore）
├── docs/
└── looper/prompts/
```

## プロジェクトの構造（統一パターン）
各プロジェクトは以下の3ファイルで構成:
```
projects/{計測名}/
├── data/            # 計測データ（.bytes, .wav, Setting.txt等）
├── config.m         # パラメータ設定（dataFolderは自分のdata/を指す）
└── runAnalysis.m    # 解析実行スクリプト（config読む→functions呼ぶ→結果出す）
```

## データフロー
```
projects/{計測名}/data/
  ├── measurepoint_*.bytes  ──→  loadBytes()    ──→ 構造体配列
  ├── *.wav                 ──→  loadWav4ch()   ──→ [4 x N] 行列
  └── Setting.txt           ──→  loadSetting()  ──→ 構造体

         ↓
    applyTranslation() → applyRotation() → filterPoints()
         ↓
    calcIntensity()  （acoustic/）
         ↓
    plotScatter3d() / plotVectorField() / plotIntensityMap()  （vis/）
         ↓
    exportCsv() / exportBytes()  （io/）
```

## 共通データ構造
loadBytes() が返す構造体配列の各要素:
```
entry.idx          - インデックス番号
entry.filename     - ファイル名
entry.filePath     - フルパス
entry.samples      - [4 x sampleLength] 音響データ
entry.sampleLength - 1chあたりのサンプル数
entry.posX/Y/Z     - 位置座標
entry.rotW/X/Y/Z   - クォータニオン回転
entry.binaryData   - 元のバイナリ（エクスポート用）
```
functions/ 内の関数はすべてこの構造体配列を入出力に使う。

## ルール
- 1関数1ファイル。ファイル名と関数名を一致させる
- functions/ は汎用。特定の計測キャンペーンに依存するコードを入れない
- 計測固有のパラメータは projects/{計測名}/config.m に書く
- パス設定は startup.m で一元管理（addpath(genpath('functions'))）
- 新しい計測を始めるときは projects/ にフォルダを作り、config.m + runAnalysis.m + data/ を置く

## App Designer化の方針（将来）
- functions/ の関数群はApp Designerのコールバックからそのまま呼び出す
- UIの状態管理はApp Designerのプロパティで行う
- functions/ には UI依存のコードを入れない（GUIとロジックを分離）
