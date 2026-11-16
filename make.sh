#!/bin/bash
# 오늘의 신조어 카드 5장(JPG)과 캡션을 만든다.
# 사용법: ./make.sh          → next.txt에 적힌 순서의 단어로 생성 (words.json은 오래된 순)
#         ./make.sh 20       → words.json의 20번째(0부터) 단어로 생성
# 필요한 것: Chrome, jq (Mac과 GitHub Actions에 기본으로 있음)
set -euo pipefail
cd "$(dirname "$0")"

I=${1:-$(cat next.txt)}
TODAY=$(date +%Y-%m-%d)
OUT="out/$TODAY"
mkdir -p "$OUT"

# card.html이 읽을 수 있게 words.json을 스크립트 파일로 감싼다.
printf 'const WORDS=%s;\n' "$(cat words.json)" > words.js

if [ -z "${CHROME:-}" ]; then
  if [ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]; then
    CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  else
    CHROME=$(command -v google-chrome || command -v chromium-browser || command -v chromium)
  fi
fi

for S in 1 2 3 4 5; do
  "$CHROME" --headless --disable-gpu --hide-scrollbars --no-sandbox \
    --force-device-scale-factor=1 --window-size=1080,1350 --virtual-time-budget=8000 \
    --screenshot="$PWD/$OUT/$S.png" "file://$PWD/card.html?i=$I&s=$S" >/dev/null 2>&1
  # 인스타그램 API는 JPG만 받는다.
  if command -v sips >/dev/null; then
    sips -s format jpeg -s formatOptions 92 "$OUT/$S.png" --out "$OUT/$S.jpg" >/dev/null
  else
    convert "$OUT/$S.png" -quality 92 "$OUT/$S.jpg"
  fi
  rm "$OUT/$S.png"
done

jq -r --argjson i "$I" '.[$i] | "오늘의 신조어: \(.word)\n\n뜻 | \(.meaning)\n\(.detail)\n\n유래 | \(.origin)\n유행 시기 | \(.peak)\n\n아는 말이었다면 댓글로 알려 주세요.\n\n#신조어 #밈 #유행어 #요즘말 #말zip #오늘의신조어 #\(.word | gsub("[^가-힣A-Za-z0-9]"; ""))"' words.json > "$OUT/caption.txt"

echo "$OUT"
