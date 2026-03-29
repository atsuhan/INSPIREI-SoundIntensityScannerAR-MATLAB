function exportBytes(outputFolder, data, reindex)
% exportBytes  計測データをbytesファイルとして出力する
%
%   exportBytes(outputFolder, data)
%   exportBytes(outputFolder, data, reindex)
%
%   入力:
%       outputFolder - 出力先フォルダパス
%       data         - 構造体配列（load_bytesの出力）
%       reindex      - true: インデックスを1から振り直す（デフォルト: true）

    if nargin < 3
        reindex = true;
    end

    if ~isfolder(outputFolder)
        mkdir(outputFolder);
    end

    for i = 1:length(data)
        if reindex
            newIdx = i;
        else
            newIdx = data(i).idx;
        end

        filename = sprintf('measurepoint_%d.bytes', newIdx);

        % バイナリデータを再構築（変換後の座標・回転を反映）
        newBinaryData = data(i).binaryData;
        sl = data(i).sampleLength;
        newBinaryData(sl * 4 + 1) = data(i).posX;
        newBinaryData(sl * 4 + 2) = data(i).posY;
        newBinaryData(sl * 4 + 3) = data(i).posZ;
        newBinaryData(sl * 4 + 4) = data(i).rotW;
        newBinaryData(sl * 4 + 5) = data(i).rotX;
        newBinaryData(sl * 4 + 6) = data(i).rotY;
        newBinaryData(sl * 4 + 7) = data(i).rotZ;

        outputPath = fullfile(outputFolder, filename);
        fid = fopen(outputPath, 'w');
        fwrite(fid, newBinaryData, 'double');
        fclose(fid);
    end

    fprintf('exportBytes: %d ファイルを出力しました (%s)\n', length(data), outputFolder);
end
