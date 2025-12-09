#!/bin/bash
# Kind 노드에서 직접 이미지를 pull하는 스크립트
# Docker Desktop의 손상된 이미지 캐시 문제를 우회

set -e

CLUSTER_NAME="wealist"

echo "=== 인프라 이미지 로드 스크립트 (Kind 노드 직접 Pull) ==="

# 필요한 인프라 이미지 목록
IMAGES=(
    "docker.io/library/postgres:15-alpine"
    "docker.io/library/redis:7-alpine"
    "docker.io/coturn/coturn:4.6"
    "docker.io/livekit/livekit-server:v1.5"
)

# Kind 노드 목록
NODES=(
    "${CLUSTER_NAME}-control-plane"
    "${CLUSTER_NAME}-worker"
    "${CLUSTER_NAME}-worker2"
)

echo ""
echo "Kind 노드에서 직접 이미지 Pull"
echo "노드: ${NODES[*]}"
echo ""

for node in "${NODES[@]}"; do
    echo "=== Node: $node ==="

    # 노드 존재 확인
    if ! docker ps --format '{{.Names}}' | grep -q "^${node}$"; then
        echo "WARNING: Node $node not found, skipping..."
        continue
    fi

    for img in "${IMAGES[@]}"; do
        echo "  Pulling: $img"
        docker exec -it "$node" crictl pull "$img" || {
            echo "  WARNING: Failed to pull $img on $node"
        }
    done
    echo ""
done

echo "=== 완료! ==="
echo ""
echo "이미지 확인:"
echo "  docker exec -it ${CLUSTER_NAME}-control-plane crictl images"
echo ""
echo "Pod 재시작:"
echo "  kubectl delete pods -n wealist-local --all"
