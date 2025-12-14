NAME="$1"
FILE="/app/clients/$NAME.txt"

if [ ! -f "$FILE" ]; then
  echo "❌ Клиент не найден"
  exit 1
fi

echo "📄 $FILE"
cat "$FILE"
