#!/bin/bash
# 인프라 이미지를 로컬 레지스트리에 푸시
# Docker Hub 로그인 필요: docker login

set -e

LOCAL_REG="localhost:5001"

echo "=== 인프라 이미지 → 로컬 레지스트리 ==="

# 레지스트리 확인
if ! curl -s "http://${LOCAL_REG}/v2/" > /dev/null 2>&1; then
    echo "ERROR: 레지스트리 없음. make kind-setup 먼저 실행"
    exit 1
fi

load() {
    local src=$1 name=$2 tag=$3
    echo "$src → ${LOCAL_REG}/${name}:${tag}"
    docker pull --platform linux/amd64 "$src"
    docker tag "$src" "${LOCAL_REG}/${name}:${tag}"
    docker push "${LOCAL_REG}/${name}:${tag}"
}

load "postgres:15-alpine" "postgres" "15-alpine"
load "redis:7-alpine" "redis" "7-alpine"
load "coturn/coturn:4.6" "coturn" "4.6"
load "livekit/livekit-server:v1.5" "livekit" "v1.5"

echo "완료!"
