function exportCsv(outputPath, data, values, mode)
% exportCsv  計測データをCSVファイルに出力する
%
%   exportCsv(outputPath, data, values, mode)
%
%   入力:
%       outputPath - 出力CSVファイルのパス
%       data       - 構造体配列（load_bytesの出力。posX/Y/Zフィールドを使用）
%       values     - 各計測点の値ベクトル [1 x N]（dB値など）
%       mode       - 'scalar' または 'vector'
%                    'scalar': PosX, PosY, PosZ, Value
%                    'vector': PosX, PosY, PosZ, NormVecX, NormVecY, NormVecZ, Value
%                    （vectorの場合はdataに.normVecX/Y/Zフィールドが必要）

    if nargin < 4
        mode = 'scalar';
    end

    fid = fopen(outputPath, 'w');
    if fid == -1
        error('exportCsv: ファイルを作成できません: %s', outputPath);
    end

    switch mode
        case 'scalar'
            fprintf(fid, 'PosX, PosY, PosZ, Value, IsRightHand\n');
            for i = 1:length(data)
                fprintf(fid, '%g,%g,%g,%g,1\n', ...
                    data(i).posX, data(i).posY, data(i).posZ, values(i));
            end

        case 'vector'
            fprintf(fid, 'PosX, PosY, PosZ, NormVecX, NormVecY, NormVecZ, Value, IsRightHand\n');
            for i = 1:length(data)
                fprintf(fid, '%g,%g,%g,%g,%g,%g,%g,1\n', ...
                    data(i).posX, data(i).posY, data(i).posZ, ...
                    data(i).normVecX, data(i).normVecY, data(i).normVecZ, ...
                    values(i));
            end

        otherwise
            fclose(fid);
            error('exportCsv: 不明なmode: %s（scalar/vectorを指定）', mode);
    end

    fclose(fid);
    fprintf('exportCsv: %d 点を出力しました (%s)\n', length(data), outputPath);
end
