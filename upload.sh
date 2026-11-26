#!/bin/bash
# make.sh가 만든 카드 5장을 인스타그램에 캐러셀(여러 장 게시물)로 올린다.
# 사용법: ./upload.sh out/2026-11-16
# 필요한 환경 변수:
#   IG_USER_ID      인스타그램 비즈니스/크리에이터 계정의 ID (숫자)
#   IG_TOKEN        게시 권한(instagram_content_publish)이 있는 액세스 토큰
#   IMAGE_BASE_URL  카드 이미지가 올라가 있는 공개 주소 (예: https://.../out/2026-11-16)
#                   인스타그램 서버가 이 주소에서 이미지를 직접 가져간다.
set -euo pipefail
cd "$(dirname "$0")"

DIR=${1:?"카드 폴더를 지정하세요. 예: ./upload.sh out/2026-11-16"}
: "${IG_USER_ID:?IG_USER_ID가 없습니다}" "${IG_TOKEN:?IG_TOKEN이 없습니다}" "${IMAGE_BASE_URL:?IMAGE_BASE_URL이 없습니다}"
# 새로 만든 Meta 앱은 "통합 로그인(비즈니스용 Facebook 로그인)" 방식만 쓸 수 있어서
# 그 방식으로 받은 시스템 사용자 토큰을 graph.facebook.com 으로 보낸다.
API="${GRAPH_API:-https://graph.facebook.com/v22.0}"

call() { # call <경로> <key=value>...  → 응답의 id를 출력, 실패하면 응답을 보여 주고 멈춘다.
  local path=$1; shift
  local args=()
  for kv in "$@"; do args+=(--data-urlencode "$kv"); done
  local res
  res=$(curl -sS -X POST "$API/$path" "${args[@]}" --data-urlencode "access_token=$IG_TOKEN")
  local id
  id=$(echo "$res" | jq -r '.id // empty')
  if [ -z "$id" ]; then echo "실패: $path → $res" >&2; exit 1; fi
  echo "$id"
}

CHILDREN=""
for S in 1 2 3 4 5; do
  ID=$(call "$IG_USER_ID/media" "image_url=$IMAGE_BASE_URL/$S.jpg" "is_carousel_item=true")
  CHILDREN="${CHILDREN:+$CHILDREN,}$ID"
done

CAROUSEL=$(call "$IG_USER_ID/media" "media_type=CAROUSEL" "children=$CHILDREN" "caption=$(cat "$DIR/caption.txt")")

status() { # 게시물 묶음의 처리 상태(FINISHED, IN_PROGRESS, PUBLISHED, ERROR 등)를 출력한다.
  curl -sS -G "$API/$CAROUSEL" --data-urlencode "fields=status_code" --data-urlencode "access_token=$IG_TOKEN" | jq -r '.status_code // "UNKNOWN"'
}

# 인스타그램이 이미지를 다 처리할 때까지 최대 2분 기다린다.
for _ in $(seq 1 12); do
  S=$(status); echo "처리 상태: $S"
  [ "$S" = "FINISHED" ] && break
  sleep 10
done

# 게시를 한 번만 요청한다. 인스타그램이 "행동이 차단되었습니다" 같은 오류를 돌려줘도 실제로는 올라가는 경우가 있어서,
# 실패하면 상태를 다시 확인하고 PUBLISHED면 성공으로 친다. (같은 단어가 두 번 올라가는 것을 막는다.)
# 차단 중에 자꾸 다시 요청하면 더 오래 막힐 수 있으므로 재시도는 하지 않는다.
if POST=$(call "$IG_USER_ID/media_publish" "creation_id=$CAROUSEL"); then
  echo "게시 완료: $POST"; exit 0
fi
sleep 30
S=$(status); echo "게시 요청 실패 후 상태: $S"
if [ "$S" = "PUBLISHED" ]; then echo "게시 완료(오류 응답이었지만 실제로 올라감)"; exit 0; fi
# 상태 값이 ERROR여도 실제로는 올라간 경우가 있었다. 계정의 최신 게시물 캡션 첫 줄이 이번 캡션과 같으면 성공으로 친다.
LATEST=$(curl -sS -G "$API/$IG_USER_ID/media" --data-urlencode "fields=caption" --data-urlencode "limit=1" --data-urlencode "access_token=$IG_TOKEN" | jq -r '.data[0].caption // ""' | head -1)
echo "계정 최신 게시물: $LATEST"
if [ -n "$LATEST" ] && [ "$LATEST" = "$(head -1 "$DIR/caption.txt")" ]; then echo "게시 완료(오류 응답이었지만 최신 게시물로 확인됨)"; exit 0; fi
echo "실패: 게시하지 못했습니다." >&2
exit 1
