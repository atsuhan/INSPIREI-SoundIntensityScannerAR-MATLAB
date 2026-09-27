function testLoadWav4ch()
% testLoadWav4ch  loadWav4ch の往復（audiowrite→loadWav4ch）テスト
%
%   4ch WAVを一時ファイルに書き出し、loadWav4chで読み込んで
%   [4 x N]・fs・値の一致（16bit量子化誤差を考慮した許容値）を確認する。
%   非4chファイルに対してerrorすることも確認する。

    fs = 16000;
    n = 800;
    t = (0:n-1)' / fs;

    % 4ch分の異なる周波数の正弦波（範囲は[-1,1)に収める）
    freqs = [100, 200, 300, 400];
    data = zeros(n, 4);
    for ch = 1:4
        data(:, ch) = 0.5 * sin(2 * pi * freqs(ch) * t);
    end

    wavPath = [tempname(), '.wav'];
    audiowrite(wavPath, data, fs, 'BitsPerSample', 16);

    try
        [samples, fsOut] = loadWav4ch(wavPath);

        assert(isequal(size(samples), [4, n]), ...
            sprintf('testLoadWav4ch: サイズが[4 x %d]ではない: [%d x %d]', ...
                n, size(samples, 1), size(samples, 2)));

        assert(fsOut == fs, ...
            sprintf('testLoadWav4ch: fsが一致しない: got=%d expected=%d', fsOut, fs));

        % 16bit量子化誤差を考慮した許容値（1 LSB相当を余裕を持って許容）
        tol = 2 / 32768;
        maxErr = max(max(abs(samples - data.')));
        assert(maxErr < tol, ...
            sprintf('testLoadWav4ch: 値の誤差が許容値超過: maxErr=%.6g tol=%.6g', maxErr, tol));
    catch err
        deleteIfExists(wavPath);
        rethrow(err);
    end

    deleteIfExists(wavPath);

    % 非4chファイルでerrorすることを確認
    wavPath3ch = [tempname(), '.wav'];
    audiowrite(wavPath3ch, data(:, 1:3), fs, 'BitsPerSample', 16);

    threw = false;
    try
        loadWav4ch(wavPath3ch);
    catch
        threw = true;
    end
    deleteIfExists(wavPath3ch);

    assert(threw, 'testLoadWav4ch: 3chファイルでerrorしなかった');
end

function deleteIfExists(p)
    if exist(p, 'file')
        delete(p);
    end
end
