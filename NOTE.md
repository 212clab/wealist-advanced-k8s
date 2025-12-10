# 빠른시작

# docker-compose 환경
./docker/scripts/dev.sh up => .env.dev 파일 주의하세요!

# local-kind 환경
make kind-setup
make k8s-deploy-registry

make status 
