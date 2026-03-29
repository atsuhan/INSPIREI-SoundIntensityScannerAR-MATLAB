% startup.m - SISARプロジェクトのパス設定
%
% このファイルがあるフォルダでMATLABを起動すると自動実行される。
% 手動で実行する場合: run('startup.m')

projectRoot = fileparts(mfilename('fullpath'));

% functions/ 以下のすべてのサブフォルダをパスに追加
addpath(genpath(fullfile(projectRoot, 'functions')));

fprintf('SISAR: パスを設定しました (%s)\n', projectRoot);
