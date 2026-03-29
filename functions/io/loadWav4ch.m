function [samples, fs] = loadWav4ch(wavPath)
% loadWav4ch  4チャンネルWAVファイルを読み込む
%
%   [samples, fs] = load_wav4ch(wavPath)
%
%   入力:
%       wavPath - WAVファイルのパス
%
%   出力:
%       samples - 音響サンプルデータ [4 x N]（行=チャンネル、列=サンプル）
%       fs      - サンプリングレート [Hz]

    if ~isfile(wavPath)
        error('loadWav4ch: ファイルが見つかりません: %s', wavPath);
    end

    [audio, fs] = audioread(wavPath);

    % チャンネル数チェック
    nChannels = size(audio, 2);
    if nChannels ~= 4
        error('loadWav4ch: 4chを期待していますが %d ch です: %s', nChannels, wavPath);
    end

    % [N x 4] → [4 x N] に転置（他の関数と統一）
    samples = audio.';

    fprintf('loadWav4ch: %d samples, Fs=%d Hz (%s)\n', size(samples, 2), fs, wavPath);
end
