function data = loadBytes(dataFolder)
% loadBytes  測定データフォルダからmeasurepoint_*.bytesを一括読み込み
%
%   data = loadBytes(dataFolder)
%
%   入力:
%       dataFolder - measurepoint_*.bytes を含むフォルダパス
%
%   出力:
%       data - 構造体配列。各要素は以下のフィールドを持つ:
%           .idx        - ファイルのインデックス番号
%           .filename   - ファイル名
%           .filePath   - フルパス
%           .samples    - 音響サンプルデータ [4 x sampleLength]
%           .sampleLength - 1chあたりのサンプル数
%           .posX, .posY, .posZ - 位置座標
%           .rotW, .rotX, .rotY, .rotZ - クォータニオン回転

    filePattern = fullfile(dataFolder, 'measurepoint_*.bytes');
    files = dir(filePattern);

    if isempty(files)
        error('loadBytes: measurepoint_*.bytes が見つかりません: %s', dataFolder);
    end

    data = [];

    for i = 1:length(files)
        % ファイル名からインデックスを抽出
        match = regexp(files(i).name, 'measurepoint_(\d+)', 'tokens');
        if isempty(match)
            continue;
        end
        idx = str2double(match{1}{1});

        filePath = fullfile(dataFolder, files(i).name);
        fid = fopen(filePath, 'r');
        if fid == -1
            warning('loadBytes: ファイルを開けません: %s', filePath);
            continue;
        end

        binaryData = fread(fid, inf, 'double').';
        fclose(fid);

        % バイナリデータを分割
        % 構成: 4ch × sampleLength + 7メタデータ (posX,Y,Z, rotW,X,Y,Z)
        sampleLength = (length(binaryData) - 7) / 4;

        entry.idx = idx;
        entry.filename = files(i).name;
        entry.filePath = filePath;
        entry.samples = reshape(binaryData(1:sampleLength*4), [sampleLength, 4]).';
        entry.sampleLength = sampleLength;
        entry.posX = binaryData(sampleLength * 4 + 1);
        entry.posY = binaryData(sampleLength * 4 + 2);
        entry.posZ = binaryData(sampleLength * 4 + 3);
        entry.rotW = binaryData(sampleLength * 4 + 4);
        entry.rotX = binaryData(sampleLength * 4 + 5);
        entry.rotY = binaryData(sampleLength * 4 + 6);
        entry.rotZ = binaryData(sampleLength * 4 + 7);
        entry.binaryData = binaryData;  % エクスポート用に保持

        data = [data, entry];
    end

    fprintf('loadBytes: %d ファイルを読み込みました (%s)\n', length(data), dataFolder);
end
