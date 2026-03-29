%% run_analysis - 2022年本庄スピーカ計測データの解析
%
%  使い方:
%    1. プロジェクトルートで startup.m を実行
%    2. このスクリプトを実行
%
%  計測条件:
%    場所: 本庄
%    対象: スピーカ
%    Fs=44100Hz, 4096サンプル, マイク間隔0.05m

clear; clc;

%% 設定読み込み
cfg = config();

%% データ読み込み
setting = loadSetting(cfg.dataFolder);
data = loadBytes(cfg.dataFolder);

fprintf('\n=== 計測条件 ===\n');
fprintf('サンプルレート: %g Hz\n', setting.sampleRate);
fprintf('サンプル長:     %d\n', setting.sampleLength);
fprintf('マイク間隔:     %.3f m\n', setting.micInterval);
fprintf('気温:           %.1f °C\n', setting.temperature);
fprintf('気圧:           %d hPa\n', setting.pressure);
fprintf('================\n\n');

%% 座標変換
data = applyTranslation(data, cfg.translateXYZ);
data = applyRotation(data, cfg.eulerAngles);

%% フィルタリング
data = filterPoints(data, cfg.filterCondition);

%% 3Dプロット
plotScatter3d(data, [], '2022 Speaker Honjo - Measurement Points');
