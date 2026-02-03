#!/bin/bash
# 🛒 家庭采买清单同步工具
# 从 Supabase 读取库存数据，同步到 Apple Reminders + Calendar
# 使用方法: ./sync-shopping.sh

set -e

SUPABASE_URL="https://syhwaeloljdswsmqkzrx.supabase.co"
SUPABASE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN5aHdhZWxvbGpkc3dzbXFrenJ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAxMDI0NjksImV4cCI6MjA4NTY3ODQ2OX0.wWe9fnjMe0d7PbXfF5s9hdY6rXHB4rCAbMzXhgbyTE8"
FAMILY_ID="dong-olivia-v2"
TODAY=$(date +%Y-%m-%d)

echo "🛒 家庭采买清单同步"
echo "===================="
echo ""

# 从 Supabase 获取数据
echo "📡 正在获取库存数据..."
DATA=$(curl -s "${SUPABASE_URL}/rest/v1/inventory?family_id=eq.${FAMILY_ID}&select=items" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}")

if [ -z "$DATA" ] || [ "$DATA" = "[]" ]; then
  echo "❌ 无法获取数据或数据为空"
  exit 1
fi

# 解析需要购买的物品（仅日用品和食材）
ITEMS=$(echo "$DATA" | jq -r '.[0].items | {daily, food} | to_entries | map(.value) | flatten | map(select(.suggest > 0 and .qty < .suggest)) | .[] | "\(.icon // "📦")|\(.name)|\(.suggest - .qty)|\(.unit // "个")"')

if [ -z "$ITEMS" ]; then
  echo "✅ 库存充足，不需要采买！"
  exit 0
fi

COUNT=$(echo "$ITEMS" | wc -l | tr -d ' ')
echo "📦 找到 ${COUNT} 件需要购买的物品"
echo ""

# 确保 Shopping 列表存在
echo "📝 准备 Reminders 列表..."
remindctl list Shopping --create 2>/dev/null || true

# 添加到 Reminders
echo "➕ 添加提醒事项..."
echo "$ITEMS" | while IFS='|' read -r icon name need unit; do
  if [ -n "$name" ]; then
    title="${icon} ${name} (${need}${unit})"
    echo "   - $title"
    remindctl add --title "$title" --list Shopping --due today 2>/dev/null || echo "     ⚠️ 添加失败: $title"
  fi
done

echo ""

# 添加日历事件 (12:05-12:10 AM，简短提醒)
echo "📅 添加日历事件..."
gog calendar create primary \
  --summary "🛒 购物提醒 - ${COUNT}件待买" \
  --from "${TODAY}T00:05:00+11:00" \
  --to "${TODAY}T00:10:00+11:00" \
  --event-color 6 2>/dev/null && echo "   ✅ 已添加日历提醒 (12:05 AM)" || echo "   ⚠️ 日历事件添加失败"

echo ""
echo "===================="
echo "✅ 同步完成！"
echo "   📝 ${COUNT} 个提醒 → Apple Reminders (Shopping)"
echo "   📅 1 个全天事件 → 日历"
echo ""
echo "💡 打开 Reminders: open -a Reminders"
