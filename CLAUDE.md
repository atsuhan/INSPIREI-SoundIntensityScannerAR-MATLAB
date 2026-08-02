@docs/rules/common.md
@docs/rules/project.md

# Claude Code

- 作業の入口と優先順位は `AGENTS.md` に従う。
- 必要な文書だけ `docs/index.md` から選ぶ。
- 共通ワークフローは `.claude/skills/`、専門Agentは `.claude/agents/` を使用する。
- 書き込みAgentへ委譲するときは、対象範囲、固有契約、受入条件、禁止事項を明示する。
- ExploreまたはPlan Agentの結果は、親Agentが固有契約と照合してから採用する。
