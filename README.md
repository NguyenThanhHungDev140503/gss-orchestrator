# GSS Orchestrator

> **G**SD + **G**Stack + **S**uperpowers — orchestrator điều phối toàn bộ vòng đời phát triển từ research → planning → review → TDD execution → QA → dispatch.

Một skill cho Claude Code (và Codex/Hermes) gói gọn 3 plugin lớn lại thành một state machine duy nhất. Orchestrator giữ context sạch bằng cách **không bao giờ gọi `Skill` tool trực tiếp** — mọi skill invocation đều đi qua subagent wrapper và chỉ trả về JSON nén.

---

## Mục lục

- [Triết lý thiết kế](#triết-lý-thiết-kế)
- [Kiến trúc 2 tầng](#kiến-trúc-2-tầng)
- [State machine](#state-machine)
- [Mapping subagent ↔ skill](#mapping-subagent--skill)
- [Luồng chi tiết một vòng skill invocation](#luồng-chi-tiết-một-vòng-skill-invocation)
- [Cơ chế blocked question (Phase 3b)](#cơ-chế-blocked-question-phase-3b)
- [Fallback path khi không có Task tool](#fallback-path-khi-không-có-task-tool)
- [Cài đặt](#cài-đặt)
- [Cấu trúc thư mục](#cấu-trúc-thư-mục)
- [Cấu hình](#cấu-hình)
- [Tham khảo nhanh](#tham-khảo-nhanh)
- [Cơ chế chống "rò rỉ" context](#cơ-chế-chống-rò-rỉ-context)
- [Skill ID conventions](#skill-id-conventions)
- [Credits](#credits)

---

## Triết lý thiết kế

Vấn đề: GSD, GStack, và Superpowers là 3 plugin mạnh nhưng mỗi plugin tự tin rằng nó là "director" của workflow. Khi gọi đồng thời, prose của chúng làm ngộp context của main session, và Claude dễ bị "trôi" theo workflow của plugin được load gần nhất.

Giải pháp của GSS Orchestrator dựa trên 4 nguyên tắc:

1. **Orchestrator là coordinator duy nhất** — GSD/GStack/Superpowers là tools, không phải directors.
2. **Subagent dispatch, never inline `Skill`** — orchestrator không có `Skill` tool, vật lý không thể gọi skill trực tiếp.
3. **JSON in, JSON out** — wrapper subagent gọi skill, follow workflow đến hết, rồi trả JSON nén theo schema cố định.
4. **Scripts là deterministic, Claude thì không** — state transitions, file writes, path resolution đều giao cho bash script.

---

## Kiến trúc 2 tầng

```text
┌─────────────────────────────────────────────────┐
│  GSS Orchestrator (SKILL.md)                    │
│  - Quản state machine, parse JSON, gọi scripts  │
│  - Tools: Bash, Read, Write, Edit, Task         │
│  - KHÔNG có Skill tool                          │
└──────────────────┬──────────────────────────────┘
                   │ Task / Agent tool
                   ▼
┌─────────────────────────────────────────────────┐
│  Wrapper subagents (gss-*)                      │
│  - Có Skill tool → load & follow plugin skill   │
│  - Trả JSON gọn về orchestrator                 │
└──────────────────┬──────────────────────────────┘
                   │ Skill tool
                   ▼
        GSD / GStack / Superpowers
```

### Tại sao 2 tầng?

| Vấn đề nếu gọi inline | Giải pháp 2 tầng |
|---|---|
| Prose của plugin polluting context | Subagent có context riêng, chỉ trả JSON |
| Claude bị "trôi" theo workflow của plugin | Orchestrator không có `Skill` tool — không thể trôi |
| Subagent nesting depth 2+ bị giới hạn | Research chạy ở depth 1 (Phase 0), không phụ thuộc GSD spawn agent |
| State khó recover sau context compaction | State sống trong `.planning/GSS_STATE.json`, không trong context |

---

## State machine

Trạng thái lưu tại `.planning/GSS_STATE.json` và được đọc đầu mỗi turn:

```text
IDLE → RESEARCH → PLANNING → GSTACK_REVIEW → SP_EXECUTING → GSTACK_QA → GSD_DISPATCH
                                        ↕
                                  GStack routing cho blocking Qs
                                  rồi quay lại SP_EXECUTING
```

| State | Trigger | Subagent dispatch |
|---|---|---|
| `IDLE` | Phiên mới khởi tạo | (chuyển ngay sang `RESEARCH`) |
| `RESEARCH` | User gửi requirements | `gss-researcher` |
| `PLANNING` | RESEARCH.md đã tạo | `gss-gsd-runner` (mode `PLANNING`) |
| `GSTACK_REVIEW` | PLAN.md đã có | `gss-reviewer` ×2 (CEO → Engineering) |
| `SP_EXECUTING` | EXEC_PROMPT.md đã ghi | `gss-executor` (qua Task tool) |
| `GSTACK_QA` | Phase báo `PHASE_COMPLETE` | `gss-qa` |
| `GSD_DISPATCH` | QA pass | `gss-gsd-runner` (mode `DISPATCH`) |
| `DELIVERED` | Hết phase trong roadmap | (in summary, kết thúc) |

---

## Mapping subagent ↔ skill

| Phase | Wrapper subagent | Skill được gọi | Plugin |
|---|---|---|---|
| 0 — RESEARCH | `gss-researcher` | (không có — dùng `WebSearch`/`WebFetch` trực tiếp) | — |
| 1 — PLANNING | `gss-gsd-runner` | `gsd-new-project` hoặc `gsd-plan-phase` | GSD |
| 2 — GSTACK_REVIEW | `gss-reviewer` | `plan-ceo-review`, rồi `plan-eng-review` | GStack |
| 3 — SP_EXECUTING | `gss-executor` | `superpowers:test-driven-development` | Superpowers |
| 3b — Blocked Q | `gss-reviewer` | `plan-ceo-review` / `plan-eng-review` / `qa` (theo router) | GStack |
| 4 — GSTACK_QA | `gss-qa` | (không có — tự chạy `npm test` / `pytest` / `go test`) | — |
| 5 — GSD_DISPATCH | `gss-gsd-runner` | `gsd-plan-phase` (cho phase tiếp theo) | GSD |

**Lưu ý:** `gss-researcher` và `gss-qa` cố ý KHÔNG có `Skill` tool. Chúng tự encapsulate logic (web search, run tests) thay vì delegate cho plugin. Đây là design quyết, không phải sót.

---

## Luồng chi tiết một vòng skill invocation

Lấy Phase 2 (CEO review) làm điển hình. Cùng một pattern lặp lại cho mọi phase có gọi skill:

```text
Orchestrator                  gss-reviewer subagent           GStack plugin
────────────                  ─────────────────────           ─────────────
1. update_state.sh
   "GSTACK_REVIEW"
2. Task(subagent_type:
        "gss-reviewer",
        prompt: "type CEO,
                 plan: ..." )──┐
                               ▼
                            3. resolve_gsd_paths.sh
                               (set $GSD_PLAN_FILE,
                                $GSD_DECISIONS_FILE,
                                $GSD_LOG_DIR)
                            4. Skill("plan-ceo-review")──────▶ load skill
                            5. Follow workflow:                 Read/Write/
                               AskUserQuestion gates,           Bash steps
                               Bash, Read, Write             ◀── completes
                            6. Save full transcript →
                               $GSD_LOG_DIR/ceo_review_*.log
                            7. Append decisions →
                               $GSD_DECISIONS_FILE
                            8. Return JSON ◀────────────────┘
9. Parse decisions[],
   không cần gọi
   log_decision.sh
10. Tiếp Phase 2 step 4
    (Engineering review,
    cùng pattern)
```

### Schema JSON trả về (ví dụ CEO/Engineering review)

```json
{
  "review_type": "CEO | ENGINEERING",
  "status": "APPROVED | NEEDS_CLARIFICATION",
  "decisions": [
    "[CEO] Acceptance criteria: login phải xong dưới 2s",
    "[ARCH] Dùng JWT RS256, không HS256 — public key phải rotatable"
  ],
  "constraints": [
    "Không breaking change cho /api/v1 hiện có"
  ],
  "open_questions": [],
  "log_file": ".planning/phases/01-auth/logs/ceo_review_1234567890.log"
}
```

---

## Cơ chế blocked question (Phase 3b)

Đây là vòng phụ thú vị nhất vì có **routing động** dựa trên keyword:

```text
gss-executor blocked
       │
       ▼
OPEN_QUESTIONS.md được ghi
       │
       ▼
route_question.sh phân loại bằng keyword regex
   business / user / scope    → /gstack:ceo
   architect / pattern / api  → /plan-eng-review
   implement / library / how  → /gstack:engineer
   edge case / validate       → /gstack:qa
   security / auth            → /plan-eng-review
   deploy / infra / env       → /gstack:release-manager
       │
       ▼
gss-reviewer (mode QUESTION_ROUTING) gọi skill tương ứng
       │
       ▼
inject_answer.sh ghi answer vào EXEC_PROMPT, retry Phase 3
```

### Bảng routing chi tiết

| Question chứa từ khóa | GStack skill | Lý do |
|---|---|---|
| business, user, scope, requirement, priority | `/gstack:ceo` | Product/business decision |
| architect, pattern, schema, api, interface, contract | `/plan-eng-review` | Architecture decision |
| implement, library, how to, algorithm, performance | `/gstack:engineer` | Technical implementation |
| edge case, validate, error, exception, null, boundary | `/gstack:qa` | QA/validation |
| security, auth, permission, encrypt, token | `/plan-eng-review` | Security cần arch review |
| deploy, infra, env, docker, k8s, ci/cd | `/gstack:release-manager` | Deployment/infra |
| (không match) | `/gstack:engineer` | Default |

---

## Fallback path khi không có Task tool

Khi Task tool không khả dụng (ví dụ Codex/Hermes installs), `SKILL.md` chỉ định fallback dùng `scripts/run_phase.sh`. Script này:

- Dùng `claude -p` subprocess với `--allowedTools "Bash,Read,Write,Edit"` (cũng không có `Skill`!).
- Parse signal `<promise>PHASE_COMPLETE</promise>` / `<promise>PHASE_BLOCKED:...</promise>` từ stdout.
- Vòng lặp tối đa `default_max_iterations` (mặc định 15) lần.
- Exit code: `0` = DONE, `1` = BLOCKED, `2` = max iter reached.

Đây là cách giữ nguyên contract "subprocess context sạch" ngay cả khi không có Task tool.

---

## Cài đặt

### Yêu cầu

- Claude Code (hoặc Codex / Hermes)
- Git repo (subagent yêu cầu)
- `jq` (installer tự cài nếu thiếu)
- 3 plugin đã cài: GSD, GStack, Superpowers

### Cách cài

```bash
# Global (dùng cho mọi project)
bash install.sh --global

# Project scope (chỉ project hiện tại)
bash install.sh --project

# Codex variant
bash install_codex.sh

# Hermes variant
bash install_hermes.sh
```

Installer sẽ:

1. Copy `SKILL.md`, `scripts/`, `references/`, `agents/` vào `~/.claude/skills/gsd-gstack-sp-orchestrator/` (hoặc `.claude/skills/...` cho project scope).
2. Deploy 5 subagent (`gss-*.md`) vào `~/.claude/agents/` hoặc `.claude/agents/`.
3. Append GSS authority block vào `CLAUDE.md` của project.

### Sau khi cài

```bash
# 1. Mở Claude Code trong project
cd /your/project && claude

# 2. Chạy setup (tạo .planning/, kiểm tra plugins, cài hooks,
#    cài Playwright + Stagehand và scaffold custom provider)
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/setup.sh

# 3. Trigger orchestrator trong Claude session:
#    "orchestrate this project for me"
#    "start gss loop"
#    "run ralph loop"
```

---

## Cấu trúc thư mục

```text
gsd-gstack-sp-orchestrator/
├── SKILL.md                    # Entry point — state machine + routing
├── SKILL.codex.md              # Codex variant (cú pháp khác)
├── CLAUDE.md                   # Authority declaration cho project
├── AGENTS.md                   # Memory context cho cross-session
├── install.sh                  # Standard installer
├── install_codex.sh            # Codex installer
├── install_hermes.sh           # Hermes installer
├── agents/                     # 5 wrapper subagents
│   ├── gss-researcher.md       #   Phase 0 — web research
│   ├── gss-gsd-runner.md       #   Phase 1, 5 — GSD wrapper
│   ├── gss-reviewer.md         #   Phase 2, 3b — GStack wrapper
│   ├── gss-executor.md         #   Phase 3 — Superpowers TDD
│   └── gss-qa.md               #   Phase 4 — test runner
├── scripts/                    # 15 deterministic helpers
│   ├── setup.sh                #   Bootstrap deps + .planning/ + browser automation
│   ├── install_browser_automation_deps.sh
│   ├── run_phase.sh            #   Fallback executor (no Task tool)
│   ├── route_question.sh       #   Keyword router cho blocked Qs
│   ├── update_state.sh         #   Cập nhật GSS_STATE.json
│   ├── checkpoint.sh           #   Snapshot trước context compaction
│   ├── log_decision.sh         #   Append vào DECISIONS.md
│   ├── write_exec_prompt.sh    #   Build EXEC_PROMPT.md cho Superpowers
│   ├── inject_answer.sh        #   Inject GStack answer vào EXEC_PROMPT
│   ├── resolve_gsd_paths.sh    #   Resolve $GSD_* env vars
│   ├── update_shared_context.sh
│   ├── summarize_gstack.sh
│   ├── print_summary.sh
│   ├── read_plugin_skill.sh
│   └── write_exec_prompt_codex.sh
├── references/                 # Templates
│   ├── CLAUDE.md.template      #   GSS authority block
│   ├── decisions-template.md
│   ├── exec-prompt-template.md
│   ├── env.stagehand.example.template
│   ├── stagehand.config.ts.template
│   ├── stagehand.example.spec.ts.template
│   └── plugin-commands.md
└── tests/
```

### State files (tạo runtime ở project user)

```text
<project>/.planning/
├── GSS_STATE.json              # Loop state, current phase
├── .project_slug               # Obsidian tag-safe project slug
├── REQUIREMENTS.md             # User input
├── RESEARCH.md                 # Phase 0 output (research source of truth)
├── ROADMAP.md                  # Phase 1 output (GSD)
├── DECISIONS.md                # Append-only audit log
├── shared_context.md           # Cross-phase context
├── config.json                 # Loop config (max iterations, ...)
├── bases/                      # Obsidian Bases query files
│   ├── project-dashboard.base
│   ├── phases.base
│   ├── research.base
│   └── decisions.base
└── phases/<phase-id>/
    ├── PLAN.md                 # GSD output cho phase này
    ├── STATE.md                # Phase state
    ├── EXEC_PROMPT.md          # Build từ PLAN.md cho Superpowers
    ├── OPEN_QUESTIONS.md       # Blocked questions (Phase 3b)
    └── logs/                   # Full GStack/QA transcripts
```

---

## Obsidian-first compatible mode

GSS giữ nguyên các file runtime hiện có làm nguồn sự thật và thêm Obsidian
frontmatter cùng các file Bases xung quanh chúng. `.planning/RESEARCH.md` vẫn là
artifact nghiên cứu mà GSD tiêu thụ; ở chế độ tương thích này research không bị
tách thành các file `research/*.md`.

- Slug dự án được tạo một lần ở Phase 0 và lưu tại `.planning/.project_slug`.
- Frontmatter được quản lý bởi `scripts/obsidian_meta.sh` (`init-project`,
  `normalize-known`, `ensure-frontmatter`).
- Các file truy vấn nằm trong `.planning/bases/` và được tạo bởi
  `scripts/obsidian_meta.sh write-bases`.
- Mở thư mục `.planning/` như một Obsidian vault (hoặc subfolder) để duyệt.

---

## Cấu hình

`.planning/config.json` được tạo tự động bởi `setup.sh`:

```json
{
  "orchestrator": "gsd-gstack-sp-orchestrator",
  "strategy": "spec-first",
  "execute_engine": "superpowers-tdd",
  "superpowers": {
    "tdd_mode": true,
    "completion_signal": "PHASE_COMPLETE",
    "blocked_signal": "PHASE_BLOCKED",
    "default_max_iterations": 15,
    "qa_retry_max_iterations": 10
  },
  "verification": {
    "require_passing_tests": true,
    "require_gstack_qa": true
  },
  "context_keys_shared": [
    "db_schema",
    "api_contracts",
    "arch_decisions",
    "env_variables",
    "type_definitions"
  ]
}
```

---

## Tham khảo nhanh

### Xem trạng thái hiện tại

```bash
cat .planning/GSS_STATE.json    # Loop state
cat .planning/STATE.md          # Phase hiện tại
cat .planning/DECISIONS.md | tail -30  # Decisions gần nhất
```

### Resume sau khi context bị compact

```bash
cat .planning/HANDOFF.json
```

Orchestrator identity sẽ resume ngay khi đọc state.

### Recovery commands

```bash
# Manual phase execution (fallback)
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/run_phase.sh

# Inject answer cho blocked phase
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/inject_answer.sh "<answer>"
```

### Triggers (gõ trong Claude session)

- `orchestrate`
- `start ralph loop`
- `run gss loop`
- `build this project`
- `start development loop`

---

## Cơ chế chống "rò rỉ" context

Bốn cơ chế bảo vệ orchestrator khỏi prose của plugin:

1. **Phân tách tool ở frontmatter**: `SKILL.md` có `allowed-tools: Bash, Read, Write, Edit, Task` — không có `Skill`. Orchestrator vật lý không thể gọi skill trực tiếp.
2. **Wrapper bắt buộc trả JSON**: mỗi agent đều có dòng `Return ONLY one of these — no prose, no skill output, no markdown narration` và schema JSON cố định.
3. **Subagent tự log decisions**: `gss-reviewer` tự append vào `DECISIONS.md`. Orchestrator chỉ chạy `update_state.sh` + `checkpoint.sh`.
4. **Boundary cho Superpowers**: `gss-executor` là biên duy nhất chạy Superpowers. MANDATORY FIRST ACTION là `Skill("superpowers:test-driven-development")`.

---

## Skill ID conventions

Quan sát được 2 cú pháp `Skill()`:

- **Plugin-namespaced**: `Skill("superpowers:test-driven-development")` — dùng trong `gss-executor`
- **Bare name**: `Skill("plan-ceo-review")`, `Skill("gsd-plan-phase")` — dùng trong `gss-reviewer`, `gss-gsd-runner`

Cú pháp phụ thuộc cách plugin đăng ký skill ID khi cài. Nếu invocation fail, kiểm tra plugin namespace bằng:

```bash
ls ~/.claude/plugins/*/skills/ 2>/dev/null
ls ~/.claude/skills/ 2>/dev/null
```

---

## Credits

- **GSD plugin**: jnuyens/gsd-plugin
- **GStack plugin**: garrytan/gstack
- **Superpowers plugin**: claude-plugins-official

GSS Orchestrator là một meta-skill — nó không thay thế 3 plugin trên mà điều phối chúng theo một state machine có kỷ luật.
