#!/bin/bash
# 인프라 이미지를 로컬 레지스트리에 푸시하는 스크립트
# 로컬 캐시 우선 사용, 없으면 AWS ECR Public에서 다운로드
# macOS bash 3.x 호환

set -e

REG_PORT="5001"
LOCAL_REG="localhost:${REG_PORT}"

echo "=== 인프라 이미지 → 로컬 레지스트리 ==="
echo "로컬 레지스트리: ${LOCAL_REG}"
echo ""

# 레지스트리 실행 확인
if ! curl -s "http://${LOCAL_REG}/v2/" > /dev/null 2>&1; then
    echo "ERROR: 로컬 레지스트리가 실행 중이 아닙니다!"
    echo "먼저 ./0.setup-cluster.sh 를 실행하세요."
    exit 1
fi

# 이미지 로드 함수 (로컬 우선, 없으면 pull)
load_image() {
    local local_name="$1"      # 로컬 이미지명 (예: postgres:15-alpine)
    local fallback_src="$2"    # 없을 때 pull할 소스 (예: public.ecr.aws/...)
    local target_name="$3"     # 레지스트리 타겟명 (예: postgres)
    local tag="$4"             # 태그 (예: 15-alpine)
    local dst="${LOCAL_REG}/${target_name}:${tag}"

    echo "Processing: $local_name → $dst"

    # 로컬에 이미지가 있는지 확인
    if docker image inspect "$local_name" > /dev/null 2>&1; then
        echo "  ✓ 로컬 캐시 사용"
    else
        echo "  로컬에 없음, 다운로드 중..."
        docker pull --platform linux/amd64 "$fallback_src"
        docker tag "$fallback_src" "$local_name"
    fi

    echo "  Tagging..."
    docker tag "$local_name" "$dst"
    echo "  Pushing to registry..."
    docker push "$dst"
    echo "  Done!"
    echo ""
}

# 이미지 로드 (로컬명, fallback소스, 타겟명, 태그)
load_image "postgres:15-alpine" "public.ecr.aws/docker/library/postgres:15-alpine" "postgres" "15-alpine"
load_image "redis:7-alpine" "public.ecr.aws/docker/library/redis:7-alpine" "redis" "7-alpine"
load_image "coturn/coturn:4.6" "public.ecr.aws/coturn/coturn:4.6" "coturn" "4.6"
load_image "livekit/livekit-server:v1.5" "livekit/livekit-server:v1.5" "livekit" "v1.5"

echo "=== 완료! ==="
echo ""
echo "로컬 레지스트리 이미지 확인:"
curl -s "http://${LOCAL_REG}/v2/_catalog" | python3 -m json.tool 2>/dev/null || curl -s "http://${LOCAL_REG}/v2/_catalog"
