#!/bin/bash
# =============================================================================
# weAlist - Development Environment Startup Script
# =============================================================================
# 개발 환경을 시작하는 스크립트입니다.
#
# 사용법:
#   ./docker/scripts/dev.sh [command] [services...]
#
# Commands:
#   start      - 빌드 없이 시작 (빠름)
#   up         - 빌드 후 시작 (기본값)
#   build      - 이미지 빌드 (특정 서비스 가능)
#   down       - 개발 환경 중지
#   restart    - 개발 환경 재시작
#   logs       - 로그 확인
#   rebuild    - 캐시 없이 전체 빌드
#   clean      - 볼륨 포함 모두 삭제
#
# Examples:
#   ./docker/scripts/dev.sh start                    # 빌드 없이 전체 시작
#   ./docker/scripts/dev.sh build video-service      # video-service만 빌드
#   ./docker/scripts/dev.sh up video-service         # video-service 빌드 + 시작
#   ./docker/scripts/dev.sh up video-service board-service  # 여러 서비스
# =============================================================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 프로젝트 루트 디렉토리로 이동
cd "$(dirname "$0")/../.."

# 환경변수 파일 확인
ENV_FILE="docker/env/.env.dev"
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${YELLOW}⚠️  환경변수 파일이 없습니다. 템플릿에서 생성합니다...${NC}"
    cp docker/env/.env.dev.example "$ENV_FILE"
    echo -e "${GREEN}✅ $ENV_FILE 파일이 생성되었습니다.${NC}"
    echo -e "${YELLOW}   필요한 값들을 수정한 후 다시 실행하세요.${NC}"
    exit 1
fi

# Docker Compose 파일 경로
COMPOSE_FILES="-f docker/compose/docker-compose.yml"

# BuildKit 활성화 (cache mount 사용을 위해 필수)
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# 환경변수 파일을 명시적으로 지정 (compose 파일 내 변수 치환용)
ENV_FILE_OPTION="--env-file $ENV_FILE"

# =============================================================================
# [⭐️ 핵심 변경 사항]: 로컬 환경 API Base URL 강제 오버라이드
#
# 프론트엔드 컨테이너의 환경 변수 VITE_API_BASE_URL을
# .env 파일 내용과 관계없이 localhost로 강제 설정합니다.
# 이 쉘 변수는 docker compose 실행 시 .env 내용을 덮어씁니다.
# =============================================================================
export VITE_API_BASE_URL="http://localhost"
echo -e "${BLUE}⚙️  로컬 개발 환경 설정: VITE_API_BASE_URL=${VITE_API_BASE_URL}${NC}"

# 커맨드 처리
COMMAND=${1:-up}
shift 2>/dev/null || true  # 첫 번째 인자 제거, 나머지는 서비스 목록

# 남은 인자들이 서비스 목록
SERVICES="$*"

# 서비스 접속 정보 출력 함수
print_service_info() {
    echo -e "${BLUE}📊 서비스 접속 정보:${NC}"
    echo "   - Frontend:    http://localhost:3000"
    echo "   - Auth API:    http://localhost:8080 (OAuth2, JWT)"
    echo "   - User API:    http://localhost:8081"
    echo "   - Board API:   http://localhost:8000"
    echo "   - Chat API:    http://localhost:8001"
    echo "   - Noti API:    http://localhost:8002"
    echo "   - Storage API: http://localhost:8003"
    echo "   - Video API:   http://localhost:8004"
    echo "   - LiveKit:     ws://localhost:7880 (WebRTC SFU)"
    echo "   - PostgreSQL:  localhost:5432"
    echo "   - Redis:       localhost:6379"
    echo "   - MinIO:       http://localhost:9000 (Console: http://localhost:9001)"
    echo -e ""
    echo -e "${BLUE}📈 모니터링:${NC}"
    echo "   - Grafana:     http://localhost:3001 (admin/admin)"
    echo "   - Prometheus:  http://localhost:9090"
    echo "   - Loki:        http://localhost:3100"
    echo -e ""
    echo -e "${BLUE}💡 로그 확인: ./docker/scripts/dev.sh logs${NC}"
}

case $COMMAND in
    start)
        # 빌드 없이 시작 (이미지가 있어야 함)
        if [ -n "$SERVICES" ]; then
            echo -e "${BLUE}🚀 서비스 시작 (빌드 없이): $SERVICES${NC}"
            docker compose $ENV_FILE_OPTION $COMPOSE_FILES up -d $SERVICES
        else
            echo -e "${BLUE}🚀 전체 서비스 시작 (빌드 없이)...${NC}"
            docker compose $ENV_FILE_OPTION $COMPOSE_FILES up -d
        fi
        echo -e "${GREEN}✅ 시작 완료${NC}"
        print_service_info
        ;;

    up)
        # 빌드 후 시작
        if [ -n "$SERVICES" ]; then
            echo -e "${BLUE}🔨 서비스 빌드 + 시작: $SERVICES${NC}"
            docker compose $ENV_FILE_OPTION $COMPOSE_FILES build $SERVICES
            docker compose $ENV_FILE_OPTION $COMPOSE_FILES up -d $SERVICES
            echo -e "${GREEN}✅ $SERVICES 시작 완료${NC}"
        else
            echo -e "${BLUE}🚀 전체 서비스 빌드 + 시작...${NC}"
            docker compose $ENV_FILE_OPTION $COMPOSE_FILES build
            docker compose $ENV_FILE_OPTION $COMPOSE_FILES up -d
            echo -e "${GREEN}✅ 개발 환경이 시작되었습니다.${NC}"
            print_service_info
        fi
        ;;

    up-fg)
        echo -e "${BLUE}🚀 개발 환경을 포그라운드로 시작합니다...${NC}"
        docker compose $ENV_FILE_OPTION $COMPOSE_FILES up
        ;;

    down)
        echo -e "${YELLOW}⏹️  개발 환경을 중지합니다...${NC}"
        docker compose $ENV_FILE_OPTION $COMPOSE_FILES down
        echo -e "${GREEN}✅ 개발 환경이 중지되었습니다.${NC}"
        ;;

    restart)
        if [ -n "$SERVICES" ]; then
            echo -e "${YELLOW}🔄 서비스 재시작: $SERVICES${NC}"
            docker compose $ENV_FILE_OPTION $COMPOSE_FILES restart $SERVICES
        else
            echo -e "${YELLOW}🔄 전체 서비스 재시작...${NC}"
            docker compose $ENV_FILE_OPTION $COMPOSE_FILES restart
        fi
        echo -e "${GREEN}✅ 재시작 완료${NC}"
        ;;

    logs)
        # logs 명령은 SERVICES 변수 대신 직접 처리
        SERVICE=${SERVICES:-}
        if [ -z "$SERVICE" ]; then
            docker compose $ENV_FILE_OPTION $COMPOSE_FILES logs -f
        else
            docker compose $ENV_FILE_OPTION $COMPOSE_FILES logs -f $SERVICE
        fi
        ;;

    build)
        # 특정 서비스 또는 전체 빌드
        if [ -n "$SERVICES" ]; then
            echo -e "${BLUE}🔨 서비스 빌드: $SERVICES${NC}"
            docker compose $ENV_FILE_OPTION $COMPOSE_FILES build $SERVICES
            echo -e "${GREEN}✅ $SERVICES 빌드 완료${NC}"
        else
            echo -e "${BLUE}🔨 전체 이미지 빌드...${NC}"
            docker compose $ENV_FILE_OPTION $COMPOSE_FILES build
            echo -e "${GREEN}✅ 전체 빌드 완료${NC}"
        fi
        ;;

    rebuild)
        # 캐시 없이 전체 빌드 (--no-cache)
        if [ -n "$SERVICES" ]; then
            echo -e "${BLUE}🔨 서비스 재빌드 (캐시 없이): $SERVICES${NC}"
            docker compose $ENV_FILE_OPTION $COMPOSE_FILES build --no-cache $SERVICES
            docker compose $ENV_FILE_OPTION $COMPOSE_FILES up -d $SERVICES
        else
            echo -e "${BLUE}🔨 전체 재빌드 (캐시 없이)...${NC}"
            docker compose $ENV_FILE_OPTION $COMPOSE_FILES build --no-cache
            docker compose $ENV_FILE_OPTION $COMPOSE_FILES up -d
        fi
        echo -e "${GREEN}✅ 재빌드 완료${NC}"
        ;;

    clean)
        echo -e "${RED}⚠️  모든 컨테이너, 볼륨, 이미지를 삭제합니다.${NC}"
        read -p "계속하시겠습니까? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker compose $ENV_FILE_OPTION $COMPOSE_FILES down -v --remove-orphans
            echo -e "${GREEN}✅ 정리가 완료되었습니다.${NC}"
        else
            echo -e "${YELLOW}취소되었습니다.${NC}"
        fi
        ;;

    ps)
        docker compose $ENV_FILE_OPTION $COMPOSE_FILES ps
        ;;

    exec)
        # exec의 경우 첫 번째가 서비스, 두 번째가 쉘
        SERVICE=${SERVICES%% *}  # 첫 번째 단어
        SHELL_CMD=${SERVICES#* }  # 나머지
        if [ "$SHELL_CMD" = "$SERVICE" ]; then
            SHELL_CMD="bash"  # 쉘 지정 안 했으면 기본값
        fi
        SERVICE=${SERVICE:-user-service}
        docker compose $ENV_FILE_OPTION $COMPOSE_FILES exec "$SERVICE" "$SHELL_CMD"
        ;;

    swagger)
        SERVICE=${SERVICES%% *}
        FORCE_FLAG=${SERVICES#* }
        SERVICE=${SERVICE:-all}
        if [ "$FORCE_FLAG" = "$SERVICE" ]; then
            FORCE_FLAG=""
        fi
        echo -e "${BLUE}📝 Swagger 문서를 생성합니다...${NC}"
        ./docker/scripts/generate-swagger.sh "$SERVICE" "$FORCE_FLAG"
        ;;

    *)
        echo -e "${RED}❌ 알 수 없는 명령어: $COMMAND${NC}"
        echo ""
        echo "사용 가능한 명령어:"
        echo ""
        echo -e "${GREEN}빠른 시작:${NC}"
        echo "  start [services...]    - 빌드 없이 시작 (가장 빠름)"
        echo "  up [services...]       - 빌드 후 시작"
        echo ""
        echo -e "${GREEN}빌드:${NC}"
        echo "  build [services...]    - 이미지 빌드 (캐시 사용)"
        echo "  rebuild [services...]  - 캐시 없이 재빌드 + 시작"
        echo ""
        echo -e "${GREEN}관리:${NC}"
        echo "  down                   - 환경 중지"
        echo "  restart [services...]  - 재시작"
        echo "  logs [services...]     - 로그 확인"
        echo "  ps                     - 실행 중인 서비스 확인"
        echo "  clean                  - 모두 삭제 (볼륨 포함)"
        echo ""
        echo -e "${GREEN}기타:${NC}"
        echo "  exec [service] [shell] - 컨테이너 접속"
        echo "  swagger [service]      - Swagger 문서 생성"
        echo ""
        echo -e "${BLUE}예시:${NC}"
        echo "  ./docker/scripts/dev.sh start                      # 빌드 없이 전체 시작"
        echo "  ./docker/scripts/dev.sh build video-service        # video-service만 빌드"
        echo "  ./docker/scripts/dev.sh up video-service           # video-service 빌드+시작"
        echo "  ./docker/scripts/dev.sh up video-service board-service  # 여러 서비스"
        echo "  ./docker/scripts/dev.sh logs video-service         # 특정 서비스 로그"
        exit 1
        ;;
esac
