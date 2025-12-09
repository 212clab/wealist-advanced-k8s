#!/bin/bash
# 서비스 이미지 빌드 후 Kind 클러스터에 로드하는 스크립트

set -e

CLUSTER_NAME="wealist"
REGISTRY="212clab"
TAG="v1"

# 색상 출력
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== 서비스 이미지 빌드 & Kind 로드 스크립트 ==="
echo ""

# 서비스별 Dockerfile 위치 매핑
declare -A SERVICES=(
    ["auth-service"]="services/auth-service"
    ["board-service"]="services/board-service"
    ["chat-service"]="services/chat-service"
    ["frontend"]="services/frontend"
    ["noti-service"]="services/noti-service"
    ["storage-service"]="services/storage-service"
    ["user-service"]="services/user-service"
    ["video-service"]="services/video-service"
)

declare -A DOCKERFILES=(
    ["auth-service"]="Dockerfile"
    ["board-service"]="docker/Dockerfile"
    ["chat-service"]="docker/Dockerfile"
    ["frontend"]="Dockerfile"
    ["noti-service"]="docker/Dockerfile"
    ["storage-service"]="docker/Dockerfile"
    ["user-service"]="docker/Dockerfile"
    ["video-service"]="docker/Dockerfile"
)

# 빌드할 서비스 선택 (인자가 없으면 전체 빌드)
if [ $# -eq 0 ]; then
    BUILD_SERVICES=("auth-service" "board-service" "chat-service" "frontend" "noti-service" "storage-service" "user-service" "video-service")
else
    BUILD_SERVICES=("$@")
fi

echo "빌드 대상: ${BUILD_SERVICES[*]}"
echo ""

# 스크립트가 실행되는 위치 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

for service in "${BUILD_SERVICES[@]}"; do
    SERVICE_PATH="${SERVICES[$service]}"
    DOCKERFILE="${DOCKERFILES[$service]}"
    IMAGE_NAME="${REGISTRY}/wealist-${service}:${TAG}"

    if [ -z "$SERVICE_PATH" ]; then
        echo -e "${RED}[ERROR] Unknown service: $service${NC}"
        continue
    fi

    echo -e "${YELLOW}[BUILD] $service${NC}"
    echo "  Path: $SERVICE_PATH"
    echo "  Dockerfile: $DOCKERFILE"
    echo "  Image: $IMAGE_NAME"

    # 빌드
    if docker build -t "$IMAGE_NAME" -f "$SERVICE_PATH/$DOCKERFILE" "$SERVICE_PATH"; then
        echo -e "${GREEN}[SUCCESS] Built $IMAGE_NAME${NC}"
    else
        echo -e "${RED}[FAILED] Failed to build $service${NC}"
        continue
    fi

    # Kind에 로드
    echo "  Loading to Kind cluster..."
    if kind load docker-image "$IMAGE_NAME" --name "$CLUSTER_NAME"; then
        echo -e "${GREEN}[SUCCESS] Loaded $IMAGE_NAME to Kind${NC}"
    else
        echo -e "${RED}[FAILED] Failed to load $service to Kind${NC}"
    fi

    echo ""
done

echo "=== 완료! ==="
echo ""
echo "배포 명령어:"
echo "  kubectl apply -k services/<service-name>/k8s/overlays/local"
echo ""
echo "또는 전체 재시작:"
echo "  kubectl rollout restart deployment -n wealist-local"
