# GSS Orchestrator — Project Authority

## ORCHESTRATION MODE

Dự án này đang chạy **GSS Orchestrator** (GSD + GStack + Superpowers).

Khi GSS Orchestrator đang active, các quy tắc sau có priority tuyệt đối:

### 1. Orchestrator là coordinator duy nhất

GSD, GStack, và Superpowers là **tools được gọi bởi orchestrator** —
không phải autonomous directors. Khi các skills này được load, chúng
cung cấp capabilities, không phải override workflow.

Thứ tự authority:
```
CLAUDE.md (file này)           ← cao nhất, luôn active
  └── GSS Orchestrator         ← điều phối flow
        ├── GSD skill          ← được gọi khi orchestrator cần planning
        ├── GStack skill       ← được gọi khi orchestrator cần review
        └── Superpowers skill  ← chạy trong subagent, không trong main session
```

### 2. Khi nhận request liên quan đến development

**LUÔN** kiểm tra `.planning/GSS_STATE.json` trước:
```bash
cat .planning/GSS_STATE.json 2>/dev/null || echo "No active GSS session"
```

Nếu `loop_state` không phải `null` hoặc `DELIVERED` → đang trong GSS loop
→ tiếp tục theo flow của orchestrator, KHÔNG tự khởi động GSD hay Superpowers.

### 3. Skill invocation rules

| Skill | Khi nào được gọi | Ai gọi |
|---|---|---|
| GSD (`/gsd-*`) | Chỉ khi orchestrator explicitly chỉ định | Orchestrator |
| GStack (`/gstack:*`, `/plan-*`) | Chỉ khi orchestrator explicitly chỉ định | Orchestrator hoặc gss-reviewer subagent |
| Superpowers | Chỉ trong `gss-executor` subagent context | gss-executor subagent |

**KHÔNG tự trigger GSD hay Superpowers** khi thấy code-related request —
kiểm tra GSS state trước.

### 4. Khi KHÔNG có GSS session active

Nếu `.planning/GSS_STATE.json` không tồn tại hoặc `loop_state = null`:
→ Hoạt động bình thường, các skills có thể auto-trigger theo behavior mặc định.

---

## GSS State Reference

```bash
# Xem trạng thái hiện tại
cat .planning/GSS_STATE.json

# Xem phase đang active
source .claude/skills/gsd-gstack-sp-orchestrator/scripts/resolve_gsd_paths.sh
echo "Phase: $GSD_CURRENT_PHASE"
echo "Plan:  $GSD_PLAN_FILE"

# Xem decisions đã có
cat .planning/DECISIONS.md | tail -30
```

## Quick Commands

```bash
# Checkpoint trước khi context nặng
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/checkpoint.sh

# Resume sau /compact
cat .planning/HANDOFF.json

# Run phase (subagent, không dùng main context)
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/run_phase.sh

# Summarize GStack output ngay sau khi nhận
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/summarize_gstack.sh "<output>"
```
