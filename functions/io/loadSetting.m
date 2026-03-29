function setting = loadSetting(dataFolder)
% loadSetting  Setting.txtから計測条件を読み込む
%
%   setting = loadSetting(dataFolder)
%
%   入力:
%       dataFolder - Setting.txt を含むフォルダパス
%
%   出力:
%       setting - 構造体:
%           .sampleRate  - サンプリングレート [Hz]
%           .sampleLength - サンプル長
%           .micInterval  - マイク間隔 [m]
%           .pressure     - 気圧 [hPa]
%           .temperature  - 気温 [°C]
%           .measuredPoints - 計測点数

    settingPath = fullfile(dataFolder, 'Setting.txt');
    if ~isfile(settingPath)
        error('loadSetting: Setting.txt が見つかりません: %s', settingPath);
    end

    fid = fopen(settingPath, 'r');
    text = textscan(fid, '%s', 'Delimiter', '\n');
    fclose(fid);
    lines = text{1};

    setting = struct();

    for i = 1:length(lines)
        line = strtrim(lines{i});
        if isempty(line)
            continue;
        end

        parts = strsplit(line, ':');
        if length(parts) < 2
            continue;
        end

        key = strtrim(parts{1});
        val = strtrim(parts{2});

        switch key
            case 'Sample Rate'
                % 'sixteen' → 16 のような文字列表現に対応
                numVal = str2double(val);
                if isnan(numVal)
                    switch lower(val)
                        case 'sixteen'
                            numVal = 16;
                        otherwise
                            warning('loadSetting: 不明なSample Rate値: %s', val);
                            numVal = 0;
                    end
                end
                setting.sampleRate = numVal;
            case 'Sample Length'
                setting.sampleLength = str2double(val);
            case 'Mic Interval'
                setting.micInterval = str2double(val);
            case 'Barometric Pressure'
                setting.pressure = str2double(val);
            case 'Temperature'
                setting.temperature = str2double(val);
            case 'Measured Points'
                setting.measuredPoints = str2double(val);
        end
    end

    fprintf('loadSetting: Fs=%g Hz, %d points, mic=%.3f m (%s)\n', ...
        setting.sampleRate, setting.measuredPoints, setting.micInterval, dataFolder);
end
