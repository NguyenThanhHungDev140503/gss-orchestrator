# EXEC_PROMPT.md — Template cho ralph-loop

File này được tạo tự động bởi `write_exec_prompt.sh`.
Đây là prompt được feed vào `/ralph-loop` — mỗi iteration Claude đọc lại file này.

## Cấu trúc

```
[1] MISSION         — tóm tắt mục tiêu của loop
[2] GSTACK DECISIONS — decisions đã approved, authoritative
[3] SHARED CONTEXT  — artifacts từ milestones trước
[4] PLAN.md         — danh sách tasks với trạng thái [ ]/[x]
[5] TDD PROTOCOL    — RED/GREEN/REFACTOR mandatory
[6] COMPLETION SIGNALS — cách output promise
[7] ITERATION AWARENESS — context về loop behavior
[8] GSTACK ANSWER (optional) — append bởi inject_answer.sh khi có blocking
```

## Tại sao PLAN.md nằm trong prompt?

Ralph-loop re-feed cùng một prompt mỗi iteration. Nhưng PLAN.md là **live file** —
Claude check off tasks [x] trong quá trình execute. Khi prompt được re-feed,
Claude đọc lại PLAN.md từ disk (không phải từ prompt text cố định), biết chính xác
task nào còn lại mà không bị confused bởi trạng thái cũ trong prompt.

Script `write_exec_prompt.sh` embed nội dung PLAN.md vào prompt lúc tạo,
nhưng Claude được instructed luôn đọc file thực từ disk trước khi bắt đầu mỗi iteration.

## Completion promise design

| Tình huống | Output | ralph-loop action |
|---|---|---|
| Tất cả tasks done, tests pass | `<promise>PHASE_COMPLETE</promise>` | Loop exit → orchestrator → GStack QA |
| Cần GStack decision | `<promise>BLOCKED:<question></promise>` | Loop exit → orchestrator → route_question → inject_answer → restart |
| Technical blocker | `<promise>BLOCKED:TECH:<desc></promise>` | Loop exit → orchestrator → /plan-eng-review → restart |
| Còn tasks nhưng chưa xong | _(không output gì)_ | Stop hook re-feed prompt → Claude tiếp tục |

## Max iterations guidance

- `15` — mặc định cho milestones bình thường
- `10` — QA retry sau failure
- `20+` — milestones phức tạp với nhiều tasks
- Luôn set `--max-iterations` — không để loop vô hạn
