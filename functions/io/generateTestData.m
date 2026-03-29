function data = generateTestData(dataFolder, numPoints, sampleLength)
% generateTestData  テスト用のダミー計測データを生成
%
%   data = generateTestData(dataFolder, numPoints, sampleLength)
%
%   入力:
%       dataFolder  - 保存先フォルダ
%       numPoints   - 生成する計測点数（デフォルト: 10）
%       sampleLength - 1chあたりのサンプル数（デフォルト: 4096）
%
%   出力:
%       data - 構造体配列（loadBytesと同じ形式）
%
%   Setting.txt と測定点*.bytesファイルを生成して、loadBytesで読み込める形式を整える

    if nargin < 2, numPoints = 10; end
    if nargin < 3, sampleLength = 4096; end

    % フォルダがなければ作成
    if ~isfolder(dataFolder)
        mkdir(dataFolder);
    end

    % === Setting.txt を生成 ===
    settingPath = fullfile(dataFolder, 'Setting.txt');
    fid = fopen(settingPath, 'w');
    fprintf(fid, 'Sample Rate: 16000\n');
    fprintf(fid, 'Sample Length: %d\n', sampleLength);
    fprintf(fid, 'Mic Interval: 0.05\n');
    fprintf(fid, 'Temperature: 25.0\n');
    fprintf(fid, 'Barometric Pressure: 1013\n');
    fprintf(fid, 'Measured Points: %d\n', numPoints);
    fclose(fid);

    % === テスト計測点データを生成 ===
    data = [];

    for i = 1:numPoints
        % ダミーサウンドデータ（4ch × sampleLength）
        % 簡単な正弦波をシミュレート
        t = (0:sampleLength-1)' / 16000;
        freq = 100 + i * 50;  % 周波数を計測点ごとに変える
        
        % 4チャンネルのダミーデータ
        samples = zeros(4, sampleLength);
        for ch = 1:4
            samples(ch, :) = 0.1 * sin(2 * pi * freq * t)' + 0.01 * randn(1, sampleLength);
        end

        % 位置座標（グリッド配置）
        gridSize = ceil(sqrt(numPoints));
        row = ceil(i / gridSize);
        col = mod(i - 1, gridSize) + 1;
        posX = (col - 1) * 0.1;
        posY = (row - 1) * 0.1;
        posZ = 0.5 + 0.05 * randn();

        % クォータニオン（初期姿勢: 単位クォータニオン）
        rotW = 1.0;
        rotX = 0.0;
        rotY = 0.0;
        rotZ = 0.0;

        % バイナリデータ構成
        binaryData = [samples(:)', posX, posY, posZ, rotW, rotX, rotY, rotZ];

        % *.bytes ファイルを保存
        bytesPath = fullfile(dataFolder, sprintf('measurepoint_%03d.bytes', i));
        fid = fopen(bytesPath, 'w');
        fwrite(fid, binaryData, 'double');
        fclose(fid);

        % 構造体配列に追加
        entry.idx = i;
        entry.filename = sprintf('measurepoint_%03d.bytes', i);
        entry.filePath = bytesPath;
        entry.samples = samples;
        entry.sampleLength = sampleLength;
        entry.posX = posX;
        entry.posY = posY;
        entry.posZ = posZ;
        entry.rotW = rotW;
        entry.rotX = rotX;
        entry.rotY = rotY;
        entry.rotZ = rotZ;
        entry.binaryData = binaryData;

        data = [data, entry];
    end

    fprintf('generateTestData: %d 点分のテストデータを生成しました\n', numPoints);
    fprintf('  保存先: %s\n', dataFolder);
end
