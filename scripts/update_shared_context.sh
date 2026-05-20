#!/usr/bin/env bash
# scripts/update_shared_context.sh
# Nhắc orchestrator extract artifacts từ milestone vừa xong vào shared_context.md

echo "━━ Shared Context Update ━━"
echo ""
echo "Extract artifacts từ milestone vừa xong vào .planning/shared_context.md"
echo "Chỉ update các keys trong config.json[context_keys_shared]:"
echo "  db_schema, api_contracts, arch_decisions, env_variables, type_definitions"
echo ""
echo "Sau khi update xong, chạy /gsd-complete-milestone"
echo "GSD sẽ hỏi milestone kế — trả lời và quay lại BƯỚC 2 (GStack review)."
