#!/bin/bash
# Docker Hub rate limiting 우회를 위해 이미지를 로컬에서 pull하고 Kind에 로드

set -e

CLUSTER_NAME="wealist"

echo "=== 인프라 이미지 로드 스크립트 ==="

# 1. 필요한 인프라 이미지 목록
IMAGES=(
    "postgres:15-alpine"
    "redis:7-alpine"
    "coturn/coturn:4.6"
    "livekit/livekit-server:v1.5"
)

echo ""
echo "Step 1: Docker 이미지 Pull"
for img in "${IMAGES[@]}"; do
    echo "Pulling: $img"
    docker pull "$img" || {
        echo "WARNING: Failed to pull $img, retrying..."
        sleep 5
        docker pull "$img"
    }
done

echo ""
echo "Step 2: Kind 클러스터에 이미지 로드"
for img in "${IMAGES[@]}"; do
    echo "Loading: $img"
    kind load docker-image "$img" --name "$CLUSTER_NAME" || {
        echo "WARNING: Failed to load $img"
    }
done

echo ""
echo "=== 완료! ==="
echo "이제 다음 명령으로 인프라를 재배포하세요:"
echo "  kubectl delete pods -n wealist-local --all"
echo "  또는"
echo "  kubectl rollout restart statefulset -n wealist-local"
