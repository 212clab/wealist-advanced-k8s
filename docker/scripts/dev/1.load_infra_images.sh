#!/bin/bash
# 인프라 이미지를 로컬 레지스트리에 푸시하는 스크립트
# Docker Hub rate limit 우회 - AWS ECR Public 사용
# macOS bash 3.x 호환

set -e

REG_PORT="5001"
LOCAL_REG="localhost:${REG_PORT}"

echo "=== 인프라 이미지 → 로컬 레지스트리 ==="
echo "로컬 레지스트리: ${LOCAL_REG}"
echo "소스: AWS ECR Public (rate limit 없음)"
echo ""

# 레지스트리 실행 확인
if ! curl -s "http://${LOCAL_REG}/v2/" > /dev/null 2>&1; then
    echo "ERROR: 로컬 레지스트리가 실행 중이 아닙니다!"
    echo "먼저 ./0.setup-cluster.sh 를 실행하세요."
    exit 1
fi

# 이미지 로드 함수
load_image() {
    local src="$1"
    local target_name="$2"
    local tag="$3"
    local dst="${LOCAL_REG}/${target_name}:${tag}"

    echo "Processing: $src → $dst"
    echo "  Pulling..."
    docker pull --platform linux/amd64 "$src"
    echo "  Tagging..."
    docker tag "$src" "$dst"
    echo "  Pushing..."
    docker push "$dst"
    echo "  Done!"
    echo ""
}

# AWS ECR Public - Docker Official Images (rate limit 없음)
load_image "public.ecr.aws/docker/library/postgres:15-alpine" "postgres" "15-alpine"
load_image "public.ecr.aws/docker/library/redis:7-alpine" "redis" "7-alpine"

# coturn - Docker Hub에서 받아야 함 (대안 없음)
# livekit도 Docker Hub에서 받아야 함
echo "Note: coturn과 livekit은 Docker Hub에서만 제공됩니다."
echo "Rate limit 걸리면 잠시 후 다시 시도하거나 docker login 하세요."
echo ""

load_image "coturn/coturn:4.6" "coturn" "4.6"
load_image "livekit/livekit-server:v1.5" "livekit" "v1.5"

echo "=== 완료! ==="
echo ""
echo "로컬 레지스트리 이미지 확인:"
curl -s "http://${LOCAL_REG}/v2/_catalog" | python3 -m json.tool 2>/dev/null || curl -s "http://${LOCAL_REG}/v2/_catalog"
