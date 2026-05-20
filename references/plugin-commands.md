# Plugin Commands — GSS Orchestrator

## Execute Engine — run_phase.sh (bash while loop + claude -p)

**Nguyên tắc:** Không chạy bất kỳ implementation code nào trong orchestrator session.
Mọi execution đi qua `run_phase.sh` → subprocess riêng → context sạch.

| Lệnh | Dùng khi |
|---|---|
| `bash scripts/run_phase.sh` | Execute phase, dùng max_iter từ config |
| `bash scripts/run_phase.sh --max-iterations 25` | Override max iterations |
| `bash scripts/run_phase.sh --mode qa_retry` | Sau QA fail, dùng qa_retry_max_iterations |

**Cấu hình max-iterations** (sửa trong `.planning/config.json`):
```json
"ralph_loop": {
  "default_max_iterations": 15,
  "qa_retry_max_iterations": 10
}
```

**Output:**
- exit 0 → DONE, all tasks complete
- exit 1 → BLOCKED, đọc `.planning/milestones/current/BLOCKED_QUESTION.txt`
- exit 2 → max iterations reached, cần review logs

---

## GSD

| Command | Dùng khi |
|---|---|
| `/gsd-new-project` | Bắt đầu project mới |
| `/gsd-new-milestone "name"` | Tạo milestone mới |
| `/gsd-complete-milestone` | Archive milestone, dispatch kế |
| `/gsd:quick "task"` | Task nhỏ, skip planning |
| `/gsd-resume` | Resume sau interrupt |

---

## GStack

| Command | Role | Dùng khi |
|---|---|---|
| `/gstack:ceo` | CEO/PM | User problem, scope, acceptance criteria |
| `/plan-ceo-review` | CEO | Full plan review từ product perspective |
| `/plan-eng-review` | Eng Manager | Architecture, feasibility, dependencies |
| `/gstack:engineer` | Tech Lead | Blocked question từ run_phase.sh |
| `/gstack:qa` | QA Lead | Validate milestone vs acceptance criteria |
| `/gstack:release-manager` | Release Mgr | Changelog, deployment |

**Routing BLOCKED_QUESTION → GStack:**
```
Question chứa                    → GStack skill
────────────────────────────────────────────────
business/user/scope/requirement → /gstack:ceo
architecture/pattern/schema/api → /plan-eng-review
implement/library/how to        → /gstack:engineer
edge case/validate/error/test   → /gstack:qa
deploy/infra/env/ci             → /gstack:release-manager
security/auth/permission        → /plan-eng-review
```

**Quan trọng:** GStack chạy trong orchestrator session — context nhẹ vì không có
implementation details. Đây là lý do orchestrator session phải giữ sạch.

---

## Flow đầy đủ

```bash
# Setup
bash scripts/setup.sh

# Milestone
/gsd-new-project
/plan-ceo-review && bash scripts/log_decision.sh "ceo-review" "..."
/plan-eng-review && bash scripts/log_decision.sh "eng-review" "..."

# Execute — subagent loop, KHÔNG dùng /ralph-loop
bash scripts/write_exec_prompt.sh
bash scripts/run_phase.sh
# → exit 0: tiếp tục QA
# → exit 1: blocked
#     bash scripts/route_question.sh "$(cat .planning/milestones/current/BLOCKED_QUESTION.txt)"
#     /gstack:engineer  (hoặc skill phù hợp)
#     bash scripts/inject_answer.sh "<answer>"
#     bash scripts/run_phase.sh  ← restart

# QA + Dispatch
/gstack:qa
/gsd-complete-milestone
bash scripts/update_shared_context.sh
# → next milestone: lặp lại từ /gsd-new-milestone
# → no more: bash scripts/print_summary.sh
```
