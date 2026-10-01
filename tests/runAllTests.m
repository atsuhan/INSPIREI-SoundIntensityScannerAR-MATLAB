function runAllTests()
% runAllTests  tests/ 以下の test*.m を全て実行し、PASS/FAILを集計する
%
%   runAllTests
%
%   使い方:
%       addpath('tests'); runAllTests
%
%   tests/test*.m という名前の関数ファイルを列挙し、それぞれを
%   try/catch で実行する。1件でもFAILがあれば最後に error を投げる
%   （終了コード非0で終わらせるため）。

    thisFile = mfilename('fullpath');
    testsDir = fileparts(thisFile);

    files = dir(fullfile(testsDir, 'test*.m'));
    nFail = 0;
    nPass = 0;

    fprintf('runAllTests: %d 件のテストを検出\n', numel(files));

    for i = 1:numel(files)
        [~, testName] = fileparts(files(i).name);
        try
            feval(testName);
            fprintf('  PASS: %s\n', testName);
            nPass = nPass + 1;
        catch err
            fprintf('  FAIL: %s\n    %s\n', testName, err.message);
            nFail = nFail + 1;
        end
    end

    fprintf('runAllTests: %d PASS, %d FAIL (total %d)\n', nPass, nFail, numel(files));

    if nFail > 0
        error('runAllTests: %d failed', nFail);
    end
end
