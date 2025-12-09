#!/bin/bash
set -e  # 에러 나면 즉시 중단



echo "🔨 [1/6] Building auth-service..."
docker build -t 212clab/wealist-auth-service:v1 -f services/auth-service/Dockerfile services/auth-service
echo "📤 Pushing auth-service..."
docker push 212clab/wealist-auth-service:v1

echo "🔨 [2/6] Building board-service..."
docker build -t 212clab/wealist-board-service:v1 -f services/board-service/docker/Dockerfile services/board-service
echo "📤 Pushing board-service..."
docker push 212clab/wealist-board-service:v1

echo "🔨 [3/6] Building chat-service..."
docker build -t 212clab/wealist-chat-service:v1 -f services/chat-service/docker/Dockerfile services/chat-service
echo "📤 Pushing chat-service..."
docker push 212clab/wealist-chat-service:v1

echo "🔨 [4/6] Building user-service..."
docker build -t 212clab/wealist-user-service:v1 -f services/user-service/docker/Dockerfile services/user-service
echo "📤 Pushing user-service..."
docker push 212clab/wealist-user-service:v1

echo "🔨 [5/6] Building noti-service..."
docker build -t 212clab/wealist-noti-service:v1 -f services/noti-service/docker/Dockerfile services/noti-service
echo "📤 Pushing noti-service..."
docker push 212clab/wealist-noti-service:v1

echo "🔨 [6/6] Building frontend..."
docker build -t 212clab/wealist-frontend:v1 -f services/frontend/Dockerfile services/frontend
echo "📤 Pushing frontend..."
docker push 212clab/wealist-frontend:v1
