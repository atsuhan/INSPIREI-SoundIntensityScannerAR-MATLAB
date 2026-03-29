%% ========================================================================
%  MeasurePoint データプロット - フィルタリング＆出力版
%  
%  フォルダ内の全ての measurepoint_*.bytes ファイルをプロット
%  フィルタリング条件に合うデータのみを別フォルダに保存
%  対象外のファイルは削除
%
%  =========================================================================

clear; clc;

%% ========================================================================
%  パラメータ設定
%  ========================================================================

dataFolder = './220523_175511_ImprezaEngineHonjo';

% 移動値 (0なら移動しない)
translateXYZ = [0, 0.85, 0.8];

% 回転値 - オイラー角 (0なら回転しない)
eulerAngles = [8, 0, 0];

% ファイル出力の有無
% false: 出力しない（プロット確認用）
% true: 出力する
doOutput = true;

% ファイル出力モード（doOutput=trueの場合のみ有効）
% 'same': 同じフォルダに上書き保存
% 'folder': 別フォルダに出力（フィルタ条件に合うデータのみ保存、対象外は削除）
outputMode = 'folder';

% フィルタリング条件
% この条件を満たすデータのみを処理します
% 例1: posY > 0        % Y > 0 のみ
% 例2: posY > 0 && posZ < 1.0  % Y > 0 かつ Z < 1.0
% 例3: true           % 全て通す（フィルタリングなし）
filterCondition = @(posX, posY, posZ) posY > 0;

%% ========================================================================
%  実行
%  =========================================================================

fprintf('=====================================\n');
fprintf('  MeasurePoint Plotter with Filter\n');
fprintf('=====================================\n\n');

fprintf('[1] Loading files from "%s"...\n', dataFolder);

% ファイル検索
filePattern = fullfile(dataFolder, 'measurepoint_*.bytes');
files = dir(filePattern);

if isempty(files)
    fprintf('Error: No measurepoint_*.bytes files found\n');
    return;
end

fprintf('✓ Found %d files\n\n', length(files));

% 出力フォルダの作成
outputFolder = '';
if strcmp(outputMode, 'folder')
    outputFolder = fullfile(dataFolder, 'Export');
    if ~isfolder(outputFolder)
        mkdir(outputFolder);
        fprintf('✓ Created output folder: %s\n\n', outputFolder);
    end
end

% ファイルを読み込んで位置データを取得
all_positions = [];
all_indices = [];
all_data = [];  % 保存用にデータを保持
filteredCount = 0;
removedFiles = {};  % 削除対象のファイル

for i = 1:length(files)
    % ファイル名からインデックスを抽出
    match = regexp(files(i).name, 'measurepoint_(\d+)', 'tokens');
    if isempty(match)
        continue;
    end
    idx = str2double(match{1}{1});
    
    % ファイルを読み込む
    filePath = fullfile(dataFolder, files(i).name);
    fid = fopen(filePath, 'r');
    if fid == -1
        continue;
    end
    
    binaryData = fread(fid, inf, 'double').';
    fclose(fid);
    
    % バイナリデータを分割
    sampleLength = (length(binaryData) - 7) / 4;
    
    % 位置データを抽出
    posX = binaryData(sampleLength * 4 + 1);
    posY = binaryData(sampleLength * 4 + 2);
    posZ = binaryData(sampleLength * 4 + 3);
    
    % 回転データを抽出
    rotW = binaryData(sampleLength * 4 + 4);
    rotX = binaryData(sampleLength * 4 + 5);
    rotY = binaryData(sampleLength * 4 + 6);
    rotZ = binaryData(sampleLength * 4 + 7);
    
    % オリジナルの回転データを保持（クォータニオン形式で回転適用用）
    quat_orig = [rotW, rotX, rotY, rotZ];
    
    % 移動を適用
    posX = posX + translateXYZ(1);
    posY = posY + translateXYZ(2);
    posZ = posZ + translateXYZ(3);
    
    % 回転を適用
    if any(eulerAngles ~= 0)
        roll = eulerAngles(1) * pi / 180;
        pitch = eulerAngles(2) * pi / 180;
        yaw = eulerAngles(3) * pi / 180;
        
        cy = cos(yaw * 0.5);
        sy = sin(yaw * 0.5);
        cp = cos(pitch * 0.5);
        sp = sin(pitch * 0.5);
        cr = cos(roll * 0.5);
        sr = sin(roll * 0.5);
        
        quat_w = cr * cp * cy + sr * sp * sy;
        quat_x = sr * cp * cy - cr * sp * sy;
        quat_y = cr * sp * cy + sr * cp * sy;
        quat_z = cr * cp * sy - sr * sp * cy;
        
        quat = [quat_w, quat_x, quat_y, quat_z];
        
        pos = [posX, posY, posZ];
        pos_rotated = quatrotate(quat, pos);
        posX = pos_rotated(1);
        posY = pos_rotated(2);
        posZ = pos_rotated(3);
        
        % クォータニオンも回転
        quat_orig = quatmultiply(quat, quat_orig);
    end
    
    % フィルタリング条件を確認（移動・回転後）
    if ~filterCondition(posX, posY, posZ)
        removedFiles = [removedFiles, {filePath}];
        continue;  % 条件に合わないデータはスキップ
    end
    filteredCount = filteredCount + 1;
    
    % 配列に追加
    all_positions = [all_positions; posX, posY, posZ];
    all_indices = [all_indices; idx];
    
    % 保存用データを格納
    data_entry.idx = idx;
    data_entry.filename = files(i).name;
    data_entry.filePath = filePath;
    data_entry.binaryData = binaryData;
    data_entry.sampleLength = sampleLength;
    data_entry.posX = posX;
    data_entry.posY = posY;
    data_entry.posZ = posZ;
    data_entry.rotW = quat_orig(1);
    data_entry.rotX = quat_orig(2);
    data_entry.rotY = quat_orig(3);
    data_entry.rotZ = quat_orig(4);
    
    all_data = [all_data, {data_entry}];
end

fprintf('[2] Plotting...\n\n');
fprintf('Total files: %d\n', length(files));
fprintf('Filtered points: %d\n', filteredCount);
fprintf('Removed files: %d\n\n', length(removedFiles));

% 左手系座標に変換（Z軸を反転）
positions_lhs = all_positions;
positions_lhs(:,3) = -positions_lhs(:,3);

% 3Dプロット
figure(1);
clf;
scatter3(positions_lhs(:,1), positions_lhs(:,2), positions_lhs(:,3), 100, all_indices, 'filled');
xlabel('X Position');
ylabel('Y Position');
zlabel('Z Position');
set(gca, 'ZDir', 'reverse');
title(sprintf('MeasurePoint Positions (%d points)', length(all_indices)));
colorbar;
grid on;
axis equal;

fprintf('✓ Plotted %d points\n', length(all_indices));

% ファイル処理
fprintf('\n[3] File Processing...\n');

if ~doOutput
    fprintf('✓ Output disabled - no files written\n');
else
    switch outputMode
    case 'folder'
        % 別フォルダに出力（インデックスを詰めて振り直し）
        for i = 1:length(all_data)
            data = all_data{i};
            
            % 新しいインデックス（詰めた番号）を作成
            newIdx = i;
            newFilename = sprintf('measurepoint_%d.bytes', newIdx);
            
            % 新しいバイナリデータを構築
            newBinaryData = data.binaryData;
            newBinaryData(data.sampleLength * 4 + 1) = data.posX;
            newBinaryData(data.sampleLength * 4 + 2) = data.posY;
            newBinaryData(data.sampleLength * 4 + 3) = data.posZ;
            newBinaryData(data.sampleLength * 4 + 4) = data.rotW;
            newBinaryData(data.sampleLength * 4 + 5) = data.rotX;
            newBinaryData(data.sampleLength * 4 + 6) = data.rotY;
            newBinaryData(data.sampleLength * 4 + 7) = data.rotZ;
            
            % 出力フォルダに保存（新しいファイル名）
            outputFilePath = fullfile(outputFolder, newFilename);
            fid = fopen(outputFilePath, 'w');
            fwrite(fid, newBinaryData, 'double');
            fclose(fid);
            
            fprintf('✓ Saved: %s (original: %s)\n', newFilename, data.filename);
        end
        
        % 削除対象ファイルを削除
        for i = 1:length(removedFiles)
            delete(removedFiles{i});
            [~, name, ext] = fileparts(removedFiles{i});
            fprintf('✗ Deleted: %s%s\n', name, ext);
        end
        
        fprintf('\n✓ Filtered data saved to: %s\n', outputFolder);
        fprintf('✓ Index renumbered (1 to %d)\n', length(all_data));
        fprintf('✓ Excluded files deleted from original folder\n');
        
    case 'same'
        % 同じフォルダに上書き保存
        for i = 1:length(all_data)
            data = all_data{i};
            
            % 新しいバイナリデータを構築
            newBinaryData = data.binaryData;
            newBinaryData(data.sampleLength * 4 + 1) = data.posX;
            newBinaryData(data.sampleLength * 4 + 2) = data.posY;
            newBinaryData(data.sampleLength * 4 + 3) = data.posZ;
            newBinaryData(data.sampleLength * 4 + 4) = data.rotW;
            newBinaryData(data.sampleLength * 4 + 5) = data.rotX;
            newBinaryData(data.sampleLength * 4 + 6) = data.rotY;
            newBinaryData(data.sampleLength * 4 + 7) = data.rotZ;
            
            % ファイルに書き込み
            fid = fopen(data.filePath, 'w');
            fwrite(fid, newBinaryData, 'double');
            fclose(fid);
            
            fprintf('✓ Saved: %s\n', data.filename);
        end
        
        fprintf('\n✓ All files saved in-place\n');
    end
end

fprintf('=====================================\n\n');