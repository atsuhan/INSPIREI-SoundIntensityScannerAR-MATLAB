# SISAR MATLAB解析ツール群

SISAR（Sound Intensity Scanner AR）で取得した計測データから音響インテンシティを計算・可視化するMATLABツール群。

## セットアップ

1. このリポジトリをクローン
2. MATLABでプロジェクトルートを開く
3. `startup.m` を実行（パス設定）

```matlab
run('startup.m')
```

## 使い方

各計測キャンペーンは `projects/` 以下にフォルダとして管理されています。

```matlab
% 1. プロジェクトフォルダに移動
cd projects/2022_impreza_engine

% 2. 計測データを data/ に配置

% 3. 解析スクリプトを実行
runAnalysis
```

サンプルは `projects/example/` を参照してください。

## ディレクトリ構成

```
SISAR/
├── startup.m              # パス設定（最初に1回実行）
├── functions/             # 共通関数
│   ├── io/                # データ読み書き（loadBytes, loadWav4ch, exportCsv 等）
│   ├── transform/         # 座標変換（applyTranslation, applyRotation 等）
│   ├── acoustic/          # 音響計算（calcIntensity 等）
│   └── vis/               # 可視化（plotScatter3d, plotVectorField 等）
├── projects/              # 計測キャンペーンごとの解析
│   ├── example/           # 使い方サンプル
│   ├── 2022_impreza_engine/
│   └── 2022_speaker_honjo/
└── archives/              # 旧コード保管
```

各プロジェクトは同じ構造を持ちます:

```
projects/{計測名}/
├── data/              # 計測データ（.gitignore対象）
├── config.m           # パラメータ設定
└── runAnalysis.m      # 解析実行スクリプト
```

## 新しい計測を追加するには

1. `projects/` に新しいフォルダを作成
2. `config.m` にパラメータを記述（座標変換、フィルタ条件等）
3. `runAnalysis.m` を作成（config読み込み→functions呼び出し→結果出力）
4. `data/` に計測データを配置

`projects/example/` をコピーして編集するのが最も簡単です。

## 必要なToolbox

- Aerospace Toolbox（quatrotate, quatmultiply）

## 関連リポジトリ

- [INSPIREI-SoundIntensityScannerAR-Unity](https://github.com/atsuhan/INSPIREI-SoundIntensityScannerAR-Unity) — 計測用XRアプリケーション
