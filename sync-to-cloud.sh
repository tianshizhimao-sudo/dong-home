#!/bin/bash
# 家庭库存云同步脚本
# 用法: ./sync-to-cloud.sh [导出的JSON文件路径]

GIST_ID="499c234f15f5202703f53c3318b49591"

if [ -z "$1" ]; then
  echo "用法: ./sync-to-cloud.sh <inventory.json路径>"
  echo "例如: ./sync-to-cloud.sh ~/Downloads/home-inventory-2026-02-03.json"
  exit 1
fi

if [ ! -f "$1" ]; then
  echo "❌ 文件不存在: $1"
  exit 1
fi

# 读取并格式化数据
DATA=$(cat "$1")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

# 创建云端格式
cat > /tmp/inventory-upload.json << EOF
{
  "lastUpdated": "$TIMESTAMP",
  "items": $DATA
}
EOF

echo "📤 正在上传到云端..."
gh gist edit $GIST_ID -f inventory.json /tmp/inventory-upload.json

if [ $? -eq 0 ]; then
  echo "✅ 同步成功！时间: $TIMESTAMP"
  echo "🔗 Gist: https://gist.github.com/tianshizhimao-sudo/$GIST_ID"
else
  echo "❌ 同步失败"
  exit 1
fi
