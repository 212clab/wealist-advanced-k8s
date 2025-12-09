#!/bin/bash
# Kind 노드 간 이미지 복사 스크립트
# control-plane에 있는 이미지를 worker 노드들로 복사

set -e

CLUSTER_NAME="wealist"
SOURCE_NODE="${CLUSTER_NAME}-control-plane"

echo "=== Kind 노드 간 이미지 복사 ==="

IMAGES=(
    "docker.io/library/postgres:15-alpine"
    "docker.io/library/redis:7-alpine"
    "docker.io/coturn/coturn:4.6"
    "docker.io/livekit/livekit-server:v1.5"
)

TARGET_NODES=(
    "${CLUSTER_NAME}-worker"
    "${CLUSTER_NAME}-worker2"
)

echo "소스 노드: $SOURCE_NODE"
echo "대상 노드: ${TARGET_NODES[*]}"
echo ""

for img in "${IMAGES[@]}"; do
    echo "=== 이미지: $img ==="

    # control-plane에서 이미지 export
    echo "  Exporting from $SOURCE_NODE..."
    docker exec "$SOURCE_NODE" ctr --namespace=k8s.io images export --platform linux/amd64 /tmp/image.tar "$img"

    # worker 노드들로 복사 및 import
    for target in "${TARGET_NODES[@]}"; do
        if ! docker ps --format '{{.Names}}' | grep -q "^${target}$"; then
            echo "  WARNING: $target not found, skipping..."
            continue
        fi

        echo "  Copying to $target..."
        docker exec "$SOURCE_NODE" cat /tmp/image.tar | docker exec -i "$target" ctr --namespace=k8s.io images import -
    done

    # 임시 파일 정리
    docker exec "$SOURCE_NODE" rm -f /tmp/image.tar
    echo ""
done

echo "=== 완료! ==="
echo ""
echo "이미지 확인:"
for node in "$SOURCE_NODE" "${TARGET_NODES[@]}"; do
    echo "  docker exec $node crictl images | grep -E 'postgres|redis|coturn|livekit'"
done
