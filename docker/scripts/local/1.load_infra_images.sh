#!/bin/bash
# 인프라 이미지를 로컬 레지스트리에 푸시하는 스크립트
# Docker Hub rate limit 완전 우회

set -e

REG_PORT="5001"
LOCAL_REG="localhost:${REG_PORT}"

echo "=== 인프라 이미지 → 로컬 레지스트리 ==="
echo "로컬 레지스트리: ${LOCAL_REG}"
echo ""

# 원본 이미지 → 로컬 레지스트리 태그 매핑
declare -A IMAGES=(
    ["postgres:15-alpine"]="${LOCAL_REG}/postgres:15-alpine"
    ["redis:7-alpine"]="${LOCAL_REG}/redis:7-alpine"
    ["coturn/coturn:4.6"]="${LOCAL_REG}/coturn:4.6"
    ["livekit/livekit-server:v1.5"]="${LOCAL_REG}/livekit:v1.5"
)

# 레지스트리 실행 확인
if ! curl -s "http://${LOCAL_REG}/v2/" > /dev/null 2>&1; then
    echo "ERROR: 로컬 레지스트리가 실행 중이 아닙니다!"
    echo "먼저 ./0.setup-cluster.sh 를 실행하세요."
    exit 1
fi

echo "Step 1: Docker Hub에서 이미지 Pull"
for src in "${!IMAGES[@]}"; do
    echo "  Pulling: $src"
    docker pull --platform linux/amd64 "$src" || {
        echo "  WARNING: Failed to pull $src"
    }
done

echo ""
echo "Step 2: 로컬 레지스트리로 Tag & Push"
for src in "${!IMAGES[@]}"; do
    dst="${IMAGES[$src]}"
    echo "  $src → $dst"
    docker tag "$src" "$dst"
    docker push "$dst"
done

echo ""
echo "=== 완료! ==="
echo ""
echo "로컬 레지스트리 이미지 확인:"
echo "  curl -s http://${LOCAL_REG}/v2/_catalog | jq"
echo ""
echo "⚠️  중요: infrastructure kustomization에서 이미지 경로 변경 필요!"
echo "  postgres:15-alpine → ${LOCAL_REG}/postgres:15-alpine"
echo "  redis:7-alpine → ${LOCAL_REG}/redis:7-alpine"
echo "  coturn/coturn:4.6 → ${LOCAL_REG}/coturn:4.6"
echo "  livekit/livekit-server:v1.5 → ${LOCAL_REG}/livekit:v1.5"
