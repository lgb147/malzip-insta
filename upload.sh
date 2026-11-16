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
sleep 10  # 인스타그램이 이미지를 처리할 시간을 준다.
POST=$(call "$IG_USER_ID/media_publish" "creation_id=$CAROUSEL")
echo "게시 완료: $POST"
