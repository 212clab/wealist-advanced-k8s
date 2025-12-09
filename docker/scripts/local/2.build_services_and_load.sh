#!/bin/bash
# 서비스 이미지 빌드 후 로컬 레지스트리에 푸시하는 스크립트
# Docker Hub rate limit 및 kind load 문제 완전 우회

set -e

REG_PORT="5001"
LOCAL_REG="localhost:${REG_PORT}"
TAG="v1"

# 색상 출력
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== 서비스 이미지 빌드 & 로컬 레지스트리 푸시 ==="
echo "로컬 레지스트리: ${LOCAL_REG}"
echo ""

# 레지스트리 실행 확인
if ! curl -s "http://${LOCAL_REG}/v2/" > /dev/null 2>&1; then
    echo -e "${RED}ERROR: 로컬 레지스트리가 실행 중이 아닙니다!${NC}"
    echo "먼저 ./0.setup-cluster.sh 를 실행하세요."
    exit 1
fi

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

# 프로젝트 루트로 이동 (스크립트는 docker/scripts/local/ 에 위치)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$PROJECT_ROOT"
echo "Working directory: $PROJECT_ROOT"
echo ""

for service in "${BUILD_SERVICES[@]}"; do
    SERVICE_PATH="${SERVICES[$service]}"
    DOCKERFILE="${DOCKERFILES[$service]}"
    IMAGE_NAME="${LOCAL_REG}/${service}:${TAG}"

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

    # 로컬 레지스트리에 푸시
    echo "  Pushing to local registry..."
    if docker push "$IMAGE_NAME"; then
        echo -e "${GREEN}[SUCCESS] Pushed $IMAGE_NAME${NC}"
    else
        echo -e "${RED}[FAILED] Failed to push $service${NC}"
    fi

    echo ""
done

echo "=== 완료! ==="
echo ""
echo "로컬 레지스트리 이미지 확인:"
echo "  curl -s http://${LOCAL_REG}/v2/_catalog | jq"
echo ""
echo "배포 명령어:"
echo "  kubectl apply -k infrastructure/overlays/local"
echo "  kubectl apply -k services/<service-name>/k8s/overlays/local"
