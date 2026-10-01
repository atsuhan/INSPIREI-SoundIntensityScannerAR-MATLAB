# Review gate

`Test-ReviewGate.ps1` は、判断確定・完了・ready PR・merge直前に独立検収記録と現在の成果物を照合する。終了コード0は指定受入範囲の整合、1はBLOCKED。調査、実装、commit、push、draft PRはBLOCKEDでも進められる。CIの既知失敗を許容する規定で、この必須ゲートを免除しない。

これは、サポートされた作業手順の整合性検査であり、署名付き証明、モデル提供者の認証、任意のGitコマンドの実行禁止ではない。編集権限のある人がJSONやログを偽造する攻撃は防げない。独立reviewerは生のログ、成果物、製品契約を実際に確認する。SHA256は証拠の入替え・古い対象の混同を検出するために使う。

## 呼び出し

受入IDと対象ファイル一覧はMilestone／確定計画から呼出側が渡し、レビュー記録から逆算しない。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/agent-harness/Test-ReviewGate.ps1 -RecordPath C:/external-evidence/review.json -Repository . -RequiredAcceptance AC-1 -ScopeFiles example/product.txt -Classification important -Json
```

複数ID／ファイルはPowerShell内でスクリプトを呼び、`-RequiredAcceptance @('AC-1','AC-2') -ScopeFiles @('src/a.cs','src/b.cs')` を渡す。正本では `agent-harness/scripts/Test-ReviewGate.ps1`、配布先では `tools/agent-harness/Test-ReviewGate.ps1` を使う。

複数repoを1回の独立セッションで検収する場合、各native markerと記録に `repositoryId`（origin URL）を加え、呼出側が `-RepositoryId https://github.com/OWNER/REPO` を渡す。該当repoのmarkerがちょうど1件だけ必要。Git repoではorigin URLも正規化して照合する。selector省略時はログ全体で1件だけという既定を維持する。他repoの承認を流用しない。

分類省略はimportant。見積、購入構成、採用、設計、数値、信号処理、単位、座標、視覚、形状、配置、法務、財務、セキュリティ、権限、発注、本番、同じ問題が2回解消しない作業はimportant。`reasons`には `estimate/purchase/adoption/design/numerical/signal/units/coordinates/visual/geometry/layout/legal/financial/security/permissions/order/production/repeated-failure` を使う。通常実装は明示的にordinary＋routineを指定する。重要理由とordinaryの組合せは拒否する。途中で対象が変わったら分類と受入範囲を更新する。

## 記録と独立検収

雛形は `templates/review-record.example.json`。プレースホルダはPASSできない。対象は `target.commit` と全対象ファイルのSHA256、または `target.kind: artifact` と全ファイルSHA256。削除対象のSHA256だけ `absent` を使う。commit方式はHEAD一致と関連ファイルのcleanを要求する。artifact方式はレビュー時と現在のhash一致を要求し、commit後にも同じ対象ファイルを再照合できる。無関係なdirtyファイルは妨げない。最終成果物を変えたら再検収する。

作者とreviewerは別ID。importantではresearcherの確認日付き証拠、上位plannerの計画PASS、plannerと別IDの上位reviewerが必要。通常reviewerはCodex `gpt-6.1-sol/high` またはClaude `opus/high`。importantはCodex `gpt-6-astra/high` またはClaude `fable/high`。自己申告やAgent定義だけではruntime証拠にならない。

reviewerの**ネイティブassistant出力**に次の1行を残す。出力は作者が代筆せず、レビュー用promptで書式を指定する。targetは記録と完全に同じcommit／path／hash、acceptanceは要求ID全件、statusは検収結果。FAILをPASSに書換えない。

```text
REVIEW_GATE_RESULT: {"status":"PASS","authorId":"AUTHOR_ID","plannerId":"PLANNER_ID","acceptance":["AC-1"],"target":{"kind":"artifact","files":[{"path":"example/product.txt","sha256":"ACTUAL_SHA256"}]}}
```

plannerは成果物作成前に受入条件と変更範囲を確定し、ネイティブassistant出力に次の1行を残す。確定範囲が変わったら再計画する。

```text
PLAN_GATE_RESULT: {"status":"PASS","acceptance":["AC-1"],"scopeFiles":["example/product.txt"]}
```

各受入IDには独立reviewのPASSと最低1つのmandatory検証が必要。mandatoryのFAIL／UNKNOWN／未実行／証拠なしは拒否する。`unverified`は空でも明記し、完了要求IDを含む未検証を残したままPASSしない。視覚理由では `visual: {viewedBy: REVIEWER_ID, image: {path, sha256}, viewingEvidence: {path, sha256}}` を追加する。画像と閲覧証拠、およびreviewerのnative tool call（Codex `view_image`、Claude `Read`、同じ画像path）が必要。wrapper経由の独自形式はadapter未対応として止める。`claims.device: true` はmandatory・PASS・`provenance: physical-device` の生証拠が必要で、static／synthetic／Editor結果だけでは成立しない。スクリプトは写真の内容や物理性能を判断しないため、reviewerが証拠の意味を照合する。

視覚ゲートはPNG／JPEG／GIFのsignatureとデコード成功を確認し、native call IDに対応する成功したimage結果が検収markerより前にあることを要求する。呼出だけ、エラー、結果欠落、検収後の閲覧、文字ファイルは拒否する。未対応の画像形式／画像結果形式はBLOCKED。

## 実行ログの対応形式

- Codex: `runtime: {path, sha256}` は保存されたネイティブrollout JSONL。`session_meta.payload.id` をactor IDと照合し、全 `turn_context.payload` のmodel・effort・`sandbox_policy.type: read-only` を確認する。CLI `--json` の `thread.started` やモデルの自己申告だけでは不足。検収は `response_item.payload` のassistant／output_textから読む。
- Claude: `runtime: {path, sha256, transcript: {path, sha256}}`。pathはCLI stream-jsonの `system/init` を含む生出力で、session_id・実モデル・実ツールを確認する。transcriptはネイティブ保存JSONLで、assistantの `sessionId`・`message.model`・top-level `effort: high` を照合する。initだけではeffortが分からない。対応モデルは `fable`／`claude-fable-*` と `opus`／`claude-opus-*`。
- Claude child: `runtime: {path, sha256}` はnative subagents/agent-*.jsonl。actor IDは共有sessionIdではなく `agentId`。assistantの `isSidechain: true`・agentId・実モデル・high effortと、`attachment.type: prompt_snapshot` の `attachment.tools[].name` を照合する。全tools snapshotが閲覧専用である必要がある。
- Claudeの許可ツールは `Read, Grep, Glob, WebFetch, WebSearch` のみ。Bash／PowerShell／Edit／Write／Skill／Task／Agent等が実ツール一覧に入れば拒否する。CLIで `--agent` を使う場合、frontmatter effortだけではmain sessionのeffortが変わらない場合があるので、`--effort high` を指定し、保存ログで確認する。
- parentのinitを子の実ツール証拠へ流用しない。childのeffective tools snapshotがない古い保存形式、未対応形式、実モデル不明、ログが取得できない環境はBLOCKED。保存ログに顧客情報や秘密が含まれる可能性があるため、公開repoへ無条件にcommitせず外部証拠パスを使う。

実際に取得したネイティブログの形式を基準にする。モデル名、保存形式が変わったらadapterと拒否テストを更新する。定義の静的一致と実起動の確認は別ゲート。

## 製品契約と検証

`docs/rules/project.md` の厳しい条件を独立検収に含める。機械検査へ追加する場合、repo所有の `docs/rules/review-policy.json` を置く。呼出側の `-PolicyPath` は追加条件としてのみ使い、repo policyを置換しない。例:

```json
{"schemaVersion":1,"classification":"important","allowedReviewerModels":["gpt-6-astra","fable"],"requiredAcceptance":["DEVICE-1"],"requiredValidationIds":["device-run"],"requireVisual":true,"requireDevice":true}
```

requiredAcceptance／requiredValidationIdsは共通条件へ追加し、classificationはimportantに強める方向だけ、allowedReviewerModelsは共通最低条件を満たすモデルの絞込みだけに使う。複数policyの受入／検証IDは和集合、visual／device条件はOR、モデル集合は積集合として必ず厳しい側を維持する。製品契約を緩めるためにpolicyや記録を編集しない。自然言語の製品契約の全内容をスクリプトだけで評価できるわけではない。

正本のシナリオ検証: `powershell -NoProfile -ExecutionPolicy Bypass -File agent-harness/scripts/Test-ReviewGateScenarios.ps1`。一時ディレクトリのみへfixtureを作り、通常／重要の経路、モデル・権限・独立性・対象鮮度・部分検収・mandatory失敗・視覚閲覧・synthetic実機誤認・厳しい製品policyを検査する。fixture成功は実モデルの起動や実機性能の証明ではない。
