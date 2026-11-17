---
name: notion
description: どのrepoからでもNotionの「タスク」DBへタスクを登録・更新し、「資料」DBへ文書を載せる。「Notionにタスク追加」「Notionに入れて」「やることに入れて」「Notionで資料化」「Notionにドキュメント化」「Notionで共有用に」「Claude担当のタスクを拾って」で使用する。
---

# Notion（タスク・資料）

どのrepoで作業していても、Notionの2つのDBへ書ける。Notion側の構成の正本は INSPIREI-Manager の `.claude/notion-structure.md`、タスクDBの欄と運用は同 `.claude/commands/add-task.md`。食い違ったら Notion を `notion-fetch` で読み直し、実際のスキーマを正とする。

## 使うDB

| 用途 | data source | DB URL |
|---|---|---|
| タスク（事務・案件・開発・個人） | `collection://19da52d4-b90d-8165-a614-000b53fbca8b` | https://app.notion.com/p/19da52d4b90d80448296cc957b0f1991 |
| 資料（共有・閲覧用。正本はrepo） | `collection://41aa52d4-b90d-816d-a0ca-000b132461bf` | https://app.notion.com/p/41aa52d4b90d81b884d7f168a15124ef |
| 議事録（参照のみ） | `collection://eb0066b1-4c1c-43cd-bc57-94abb4fffc3c` | https://app.notion.com/p/bff06017eab74f32aa4e9b0f3cd854e8 |

「Claude担当」ビュー: `view://41aa52d4-b90d-8135-82e5-000c036dee4c`（担当=Claude かつ未完了）。
プロジェクト別ビュー（未完了、`自走` でグループ）: OTOMIRU `view://41ba52d4-b90d-81bc-8d18-000c87580ccc`、SISAR `view://41ba52d4-b90d-81b1-8227-000cd7350a19`、東京ガス `view://41ba52d4-b90d-8137-8b3d-000c0ed3d80d`。

## 開発タスクは「常時対応」カードに書く（1件1行にしない）

- タスクDBは事務・案件・個人のやることを埋もれさせないための場所。repoの開発タスク（MILESTONESのID）は **1件ずつ行にしない**。プロジェクトごとに1枚ある `ステータス=常時対応` のカード「<プロジェクト> 開発 — いまの取り組み」の本文に、全件を書く（上位だけでなく中身全部）。
  - OTOMIRU: `https://app.notion.com/p/41aa52d4b90d81f3b4adc0f430323d40`
  - SISAR: `https://app.notion.com/p/41ba52d4b90d81ee9cc1d9dedc4ed359`
  - 東京ガス（PipeScanner）: `https://app.notion.com/p/41ba52d4b90d81759a62dab4cfb83f9a`
  - その他（JRC・InagiTama 単独など）: タスクDBを `notion-search` で「開発 — いまの取り組み」と探す。無いプロジェクトは同じ形式で1枚作る（`ステータス=常時対応`、`起票元=MILESTONES`、`自走=自走可`、`担当=Claude`、`重要度=高`）。
- 本文の節「## 開発タスク一覧（MILESTONES の写し）」の形式:
  - 冒頭に「正本は各repoの docs/roadmap/MILESTONES.md。YYYY-MM-DD 時点」と件数サマリ（全件・自走可・一部自走・要人手）。
  - `### 自走可`／`### 一部自走`／`### 要人手` → `#### <repo>` → 表 `| ID | タスク | 状態 | 重要度 | 自走メモ | 完了条件 | 関連 |`。状態は 直近対応目標→対応中→待ち→未着手 の順。完了したものは表から外す。
  - 自走の区分: `自走可`＝repo内の実装・文書・テストで完了しAgentが検証できる／`一部自走`＝準備・実装はAgentが進めるが完了判定に実機・目視・井上確認が要る／`要人手`＝発注・現場・実機計測・外部回答・井上の裁定が先に要る。自走可以外は自走メモに人が要る理由を1文。
- 更新のタイミング: そのrepoでPRをマージした区切り（MILESTONESのタスクを追加・完了・保留・改題したとき）に、このカードの該当repoの行だけを差し替える（`notion-update-page` の `update_content`）。カード内の他repoの行や、他の節（OTOMIRUの TASKS.md 由来の節など）は触らない。
- 例外: 期限管理が要る開発の節目（納品日・客先デモ・申請締切など人が動く日付）だけは、タスクDBに1行作ってよい（`起票元=MILESTONES`、`タスクID`、`repo` を入れ、カードと二重に中身を書かない）。

## 前提

- Notion MCP（`notion-search`、`notion-fetch`、`notion-create-pages`、`notion-update-page`、`notion-query-data-sources`）を使う。接続されていなければ、その事実を伝えて止める。URLを推測して別手段で書き込まない。
- 無料プラン: SQLクエリは回数上限があるので、読むときはビュー（`mode: "view"`）を優先する。添付は1ファイル5MBまで。大きいファイルはDriveに置いてリンクする。
- 自分のNotionワークスペースへの作成・更新はユーザー依頼の範囲で行ってよい。コメント、mention、共有設定の変更、外部への公開・招待は他者へ届くため、`docs/rules/common.md`「人間への送信前確認」に従い、内容と宛先を提示して承認を待つ。
- 秘密情報（鍵・トークン・パスワード）は書かない。顧客の個人情報・見積金額は、ユーザーが明示した場合だけ載せる。

## repo → プロジェクト

既定値。依頼内容が別案件なら依頼を優先する。

| repo | タスクDB「プロジェクト」 | 資料DB「プロジェクト」 |
|---|---|---|
| INSPIREI-OTOMIRU-*（InagiTama を含む） | OTOMIRU | OTOMIRU |
| INSPIREI-JRC-Unity | JRC | JRC |
| INSPIREI-PipeScanner-* | PipeScanner（東京ガス案件なら 東京ガス も） | 同左 |
| INSPIREI-SoundIntensityScannerAR-* | SISAR | SISAR |
| INSPIREI-VisualizationBaseSystem | （該当なし。聞く） | 可視化 |
| INSPIREI-Web | HP | HP |
| INSPIREI-Manager | 内容から判断（事務・案件名） | 同左 |
| INSPIREI（Master）／BigBaitTokyo-Web | 内容から判断。該当がなければ空 | 同左 |

## A. タスクを登録する

1. 内容を「動詞で終わる1行」のタイトルにする。期限・担当が分からなければ1回だけ聞く（期限と担当が決まれば登録してよい）。半日を超えるなら分割を提案する。
2. 重複確認: `notion-search` に `data_source_url`（タスクDB）を付けて、タイトルの主要語で探す。あれば新規作成せず更新する。
3. `notion-create-pages`（parent はタスクDBの data source）で作る。欄:
   - `Name`（title）、`ステータス`（未着手／直近対応目標／対応中／待ち／完了／常時対応）、`date:期限:start`、`担当`（井上／Claude／外部）、`プロジェクト`（上の表）、`重要度`（高／中／低）
   - `完了条件`: 何をもって終わりか。工程ごとに（井上）（Claude）を付ける
   - `関連`: このrepo名と、関係するパス・`docs/roadmap/MILESTONES.md` のID・PR番号（例 `INSPIREI-OTOMIRU-Unity MILESTONES FTR-29d / PR #1381`）
   - `GitHub Issue`: 関係するIssueがあるときだけURL
   - `自走`: `自走可`（repo内の実装・文書・テストで完了し、受け入れ条件をAgentが検証できる）／`一部自走`（準備・実装はAgentが進められるが、完了判定に実機・目視・井上確認が要る）／`要人手`（発注・現場・実機計測・外部回答・井上の裁定が先に要る）
   - `自走メモ`: 自走可以外は、人が要る理由を1文
   - `起票元`: `MILESTONES`（repoの台帳にIDがある）／`Notion`（Notionで起票）／`GitHub Issue`。MILESTONESにあるなら `タスクID` にID、`repo` にrepo名を入れる
4. 開発タスクの扱い: repoの作業台帳は引き続き `docs/roadmap/MILESTONES.md` が正本。開発タスクは行を作らず、上の「常時対応」カードの本文に書く（「Notionに入れて」と言われた開発タスクも同じ）。
5. 報告: タイトル・期限・担当・NotionのURLを1行ずつ。

## B. タスクを拾う・閉じる

- 作業開始時に「Claude担当のタスクを拾って」と言われたら、「Claude担当」ビューを `notion-query-data-sources`（view モード）で読み、このrepoのプロジェクトに当たるものを示す。
- 完了時: `ステータス` を「完了」にし、本文末尾に `YYYY-MM-DD 完了: 何をしたか・成果物のパス／PR` を1行追記する。人の工程が残るなら「待ち」にして担当を井上へ。
- スマホからタイトルだけ入ったタスク（担当・プロジェクトが空）は、気づいたら欄を埋める。
- repoでMILESTONESのタスクを完了・保留・改題・追加したら、PRマージの区切りでプロジェクトの「常時対応」カードの該当行を更新する（MILESTONESが正本）。例外として行を作った節目タスク（`起票元=MILESTONES`）があれば、同じ `タスクID`＋`repo` の行も閉じる。

## C. 資料（ドキュメント）にする

1. 正本はrepoに置く。Notionは共有・閲覧用の写し。まだrepoに無い文書なら、先にrepoへ書いてcommitするか、Notionだけで良いかを確認する（使い捨ての共有メモならNotionだけでよい）。
2. 重複確認: `notion-search`（資料DB）で同名・同内容を探す。あれば更新し、古い版はアーカイブ（`.claude/notion-structure.md` のアーカイブページ）へ移すかユーザーに確認する。
3. `notion-create-pages`（parent は資料DBの data source）で作る。欄:
   - `Name`: 文書名（版や日付が要るなら付ける）
   - `カテゴリ`: 提案・申請／見積・契約／技術メモ／会社（開発の仕様・設計・調査は「技術メモ」）
   - `プロジェクト`: 上の表
   - `正本`: `<repo名>/<パス>@<commit SHA 先頭9桁>`（Notionだけの文書なら `Notionのみ`）
   - `共有先`: ユーザーが指定したときだけ書く。書いただけでは誰にも通知されないが、実際の共有操作は承認を取る
4. 本文: repoの Markdown を Notion-flavored Markdown に変換して全文を載せる（要約で置き換えない）。冒頭に「正本: repo パス・commit、最終同期日」を1行入れる。画像・大きな添付はリンクにする。
5. repoの正本を更新したら、同じページを更新して `正本` のSHAと同期日を上げる。逆方向（Notionで直した内容）は、ユーザーが求めたときだけrepoへ取り込む。
6. 報告: ページ名・カテゴリ・NotionのURL・正本のパス。

## やらないこと

- 議事録DBへの書き込み（議事録は Manager の運用）。決まったToDoはタスクDBへ、決定事項はrepoの正本へ移す。
- Notionとrepoの自動同期（廃止済みの `/notion-sync` を復活させない）。
- 他者へのmention・コメント・招待・公開を承認なしに行うこと。
