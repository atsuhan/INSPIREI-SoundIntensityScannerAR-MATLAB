function testCalcCrossSpectrum()
% testCalcCrossSpectrum  calcCrossSpectrum の数値検証（Parseval・対称性・周波数軸）

    fs = 16000;
    duration = 2;
    n = fs * duration;
    t = (0:n - 1)' / fs;
    nfft = 1024;

    A = 1;
    f0 = 500; % nfft=1024, fs=16000 のビン中心周波数（bin幅=15.625Hz）
    x = A * sin(2 * pi * f0 * t);

    [gxx, freq] = calcCrossSpectrum(x, x, fs, nfft, 0.5);

    % (1) Parseval: sum(real(gxx)) ≈ mean(x.^2)
    meanX2 = mean(x .^ 2);
    sumRealGxx = sum(real(gxx));
    relErrParseval = abs(sumRealGxx - meanX2) / meanX2;
    assert(relErrParseval < 0.01, ...
        sprintf('testCalcCrossSpectrum: Parseval誤差過大: relErr=%.6g (sumRealGxx=%.6g, meanX2=%.6g)', ...
            relErrParseval, sumRealGxx, meanX2));

    % (2) 自己相関スペクトルは実数（imag部はゼロに近い）
    maxImagGxx = max(abs(imag(gxx)));
    maxRealGxx = max(real(gxx));
    assert(maxImagGxx < 1e-9 * maxRealGxx, ...
        sprintf('testCalcCrossSpectrum: gxxの虚部が非ゼロ: maxImag=%.6g maxReal=%.6g', ...
            maxImagGxx, maxRealGxx));

    % (3) 共役対称性: gyx == conj(gxy)
    f1 = 1000; % ビン中心周波数
    y = A * cos(2 * pi * f1 * t);
    [gxy, ~] = calcCrossSpectrum(x, y, fs, nfft, 0.5);
    [gyx, ~] = calcCrossSpectrum(y, x, fs, nfft, 0.5);
    maxDiff = max(abs(gyx - conj(gxy)));
    maxGxy = max(abs(gxy));
    assert(maxDiff < 1e-9 * maxGxy, ...
        sprintf('testCalcCrossSpectrum: gyx != conj(gxy): maxDiff=%.6g maxGxy=%.6g', ...
            maxDiff, maxGxy));

    % (4) 周波数軸
    assert(freq(1) == 0, 'testCalcCrossSpectrum: freq(1) != 0');
    assert(abs(freq(end) - fs / 2) < eps(fs), ...
        sprintf('testCalcCrossSpectrum: freq(end) != fs/2: got=%.6g', freq(end)));
    assert(numel(freq) == nfft / 2 + 1, ...
        sprintf('testCalcCrossSpectrum: freqの長さがnfft/2+1ではない: got=%d expected=%d', ...
            numel(freq), nfft / 2 + 1));
end
