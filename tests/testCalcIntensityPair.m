function testCalcIntensityPair()
% testCalcIntensityPair  calcIntensityPair の物理量・符号・帯域積算の検証

    fs = 16000;
    duration = 2;
    n = fs * duration;
    t = (0:n - 1)' / fs;

    rho = 1.2041;
    c = 343.2;
    dr = 0.05;
    A = 1;
    iTrue = A ^ 2 / (2 * rho * c);

    f0 = 500; % nfft=1024, fs=16000 のビン中心周波数
    k0 = 2 * pi * f0 / c;
    finiteDiffFactor = sin(k0 * dr) / (k0 * dr);
    iExp = iTrue * finiteDiffFactor;

    p1 = A * sin(2 * pi * f0 * t);
    p2 = A * sin(2 * pi * f0 * (t - dr / c)); % mic1→mic2方向へ伝搬

    % --- (1) 順方向: 有限差分補正込みで理論値と一致 ---
    resFwd = calcIntensityPair(p1, p2, fs, dr, rho);

    relErrExp = abs(resFwd.intensity - iExp) / iExp;
    assert(relErrExp < 0.01, ...
        sprintf('testCalcIntensityPair(1): 有限差分補正込み理論値との誤差過大: relErr=%.6g', relErrExp));

    relErrTrue = abs(resFwd.intensity - iTrue) / iTrue;
    assert(relErrTrue < 0.05, ...
        sprintf('testCalcIntensityPair(1): 理論値(無補正)との誤差過大: relErr=%.6g', relErrTrue));

    assert(resFwd.sign == 1, ...
        sprintf('testCalcIntensityPair(1): signが+1ではない: got=%d', resFwd.sign));

    % --- (2) 物理的に逆方向（mic2→mic1へ伝搬）: I_rev ≈ -I_fwd ---
    p1Rev = A * sin(2 * pi * f0 * (t - dr / c));
    p2Rev = A * sin(2 * pi * f0 * t);
    resRev = calcIntensityPair(p1Rev, p2Rev, fs, dr, rho);

    sumAbs = abs(resRev.intensity + resFwd.intensity);
    tolRev = 1e-6 * abs(resFwd.intensity);
    assert(sumAbs < tolRev, ...
        sprintf('testCalcIntensityPair(2): I_rev + I_fwd が許容値超過: sumAbs=%.6g tol=%.6g', ...
            sumAbs, tolRev));

    % --- (3) 引数入替で符号反転 ---
    resSwapped = calcIntensityPair(p2, p1, fs, dr, rho);
    assert(resSwapped.sign == -1, ...
        sprintf('testCalcIntensityPair(3): 引数入替でsignが反転していない: got=%d', resSwapped.sign));
    swapDiff = abs(resSwapped.intensity + resFwd.intensity);
    tolSwap = 1e-6 * abs(resFwd.intensity);
    assert(swapDiff < tolSwap, ...
        sprintf('testCalcIntensityPair(3): 引数入替の対称性が不十分: diff=%.6g tol=%.6g', ...
            swapDiff, tolSwap));

    % --- (4) p1==p2（垂直入射相当）: |I| がほぼゼロ ---
    resSame = calcIntensityPair(p1, p1, fs, dr, rho);
    tolSame = 1e-3 * abs(resFwd.intensity);
    assert(abs(resSame.intensity) < tolSame, ...
        sprintf('testCalcIntensityPair(4): p1==p2でIがゼロに近くない: |I|=%.6g tol=%.6g', ...
            abs(resSame.intensity), tolSame));

    % --- (5) dB誤差 < 0.1 dB ---
    dbExp = 10 * log10(abs(iExp) / 1e-12);
    dbErr = abs(resFwd.intensityLevelDb - dbExp);
    assert(dbErr < 0.1, ...
        sprintf('testCalcIntensityPair(5): dB誤差過大: dbErr=%.6g dB', dbErr));

    % --- (6) 帯域指定: [400 600]は(1)と同値、[1000 2000]はほぼゼロ ---
    opts600 = struct('band', [400, 600]);
    resBand600 = calcIntensityPair(p1, p2, fs, dr, rho, opts600);
    diffBand600 = abs(resBand600.intensity - resFwd.intensity);
    tolBand600 = 1e-6 * abs(resFwd.intensity);
    assert(diffBand600 < tolBand600, ...
        sprintf('testCalcIntensityPair(6a): band[400,600]が(1)と一致しない: diff=%.6g tol=%.6g', ...
            diffBand600, tolBand600));

    opts2000 = struct('band', [1000, 2000]);
    resBand2000 = calcIntensityPair(p1, p2, fs, dr, rho, opts2000);
    tolBand2000 = 1e-3 * abs(resFwd.intensity);
    assert(abs(resBand2000.intensity) < tolBand2000, ...
        sprintf('testCalcIntensityPair(6b): band[1000,2000]でIがゼロに近くない: |I|=%.6g tol=%.6g', ...
            abs(resBand2000.intensity), tolBand2000));

    % --- (7) 2トーン（500Hz+1000Hz）: 総和が理論値和と2%以内 ---
    f1b = 1000;
    k1b = 2 * pi * f1b / c;
    iExp1b = iTrue * sin(k1b * dr) / (k1b * dr);

    p1Two = A * sin(2 * pi * f0 * t) + A * sin(2 * pi * f1b * t);
    p2Two = A * sin(2 * pi * f0 * (t - dr / c)) + A * sin(2 * pi * f1b * (t - dr / c));
    resTwo = calcIntensityPair(p1Two, p2Two, fs, dr, rho);

    iExpTotal = iExp + iExp1b;
    relErrTwo = abs(resTwo.intensity - iExpTotal) / iExpTotal;
    assert(relErrTwo < 0.02, ...
        sprintf('testCalcIntensityPair(7): 2トーン総和が理論値和と一致しない: relErr=%.6g', relErrTwo));
end
