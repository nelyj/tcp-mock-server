#!/bin/bash
HOST=${HOST:-localhost}
PORT=${PORT:-9000}

NOW_DATE=$(date +%Y%m%d)
NOW_TIME=$(date +%H%M%S)

MESSAGE=$(printf "\x02%s%s%s%s%s\x03" "96" "TL" "000001" "$NOW_DATE" "$NOW_TIME")

echo -e "$MESSAGE" | nc $HOST $PORT