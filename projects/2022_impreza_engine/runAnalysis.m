%% run_analysis - 2022年インプレッサエンジン計測データの解析
%
%  使い方:
%    1. プロジェクトルートで startup.m を実行
%    2. このスクリプトを実行
%
%  計測条件:
%    場所: 本庄
%    対象: スバルインプレッサ エンジン
%    Fs=16Hz, 4096サンプル, マイク間隔0.05m

clear; clc;

%% 設定読み込み
cfg = config();

%% データ読み込み
% データがない場合はテストデータを生成
if ~isfile(fullfile(cfg.dataFolder, 'Setting.txt'))
    fprintf('\n警告: Setting.txt が見つかりません\n');
    fprintf('テスト用のダミーデータを生成します...\n\n');
    generateTestData(cfg.dataFolder, 10, 4096);
end

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
fig = plotScatter3d(data, [], '2022 Impreza Engine - Measurement Points');

%% 成果物の保存
outputFolder = cfg.outputFolder;
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

% PNGファイルを保存
pngPath = fullfile(outputFolder, 'measurement_points_3d.png');
saveas(fig, pngPath);
fprintf('\n✓ PNG保存: %s\n', pngPath);

% MATファイルを保存（データと設定）
matPath = fullfile(outputFolder, 'analysis_results.mat');
save(matPath, 'data', 'setting', 'cfg');
fprintf('✓ MAT保存: %s\n', matPath);

close(fig);
fprintf('\n===== 解析完了 =====\n');
