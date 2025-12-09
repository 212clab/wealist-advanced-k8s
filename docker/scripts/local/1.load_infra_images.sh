#!/bin/bash
# Docker Hub rate limiting 우회를 위해 이미지를 로컬에서 pull하고 Kind에 로드
# 손상된 이미지 캐시 문제 해결을 위해 기존 이미지 삭제 후 재다운로드

set -e

CLUSTER_NAME="wealist"

echo "=== 인프라 이미지 로드 스크립트 ==="

# 필요한 인프라 이미지 목록
IMAGES=(
    "postgres:15-alpine"
    "redis:7-alpine"
    "coturn/coturn:4.6"
    "livekit/livekit-server:v1.5"
)

echo ""
echo "Step 1: 기존 이미지 삭제 (손상된 캐시 정리)"
for img in "${IMAGES[@]}"; do
    echo "Removing: $img"
    docker rmi "$img" 2>/dev/null || true
done

echo ""
echo "Step 2: Docker 이미지 Pull (linux/amd64)"
for img in "${IMAGES[@]}"; do
    echo "Pulling: $img"
    docker pull --platform linux/amd64 "$img" || {
        echo "WARNING: Failed to pull $img, retrying..."
        sleep 5
        docker pull --platform linux/amd64 "$img"
    }
done

echo ""
echo "Step 3: Kind 클러스터에 이미지 로드"
for img in "${IMAGES[@]}"; do
    echo "Loading: $img"
    kind load docker-image "$img" --name "$CLUSTER_NAME" || {
        echo "ERROR: Failed to load $img"
        echo "Trying alternative method: docker save | docker exec"
        docker save "$img" | docker exec -i "${CLUSTER_NAME}-control-plane" ctr --namespace=k8s.io images import - || {
            echo "WARNING: Alternative method also failed for $img"
        }
    }
done

echo ""
echo "=== 완료! ==="
echo "이제 pod를 재시작하세요:"
echo "  kubectl delete pods -n wealist-local --all"
