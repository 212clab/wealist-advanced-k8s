# auth-service
docker build -t 212clab/wealist-auth-service:v1 -f services/auth-service/Dockerfile services/auth-service
docker push 212clab/wealist-auth-service:v1

# board-service
docker build -t 212clab/wealist-board-service:v1 -f services/board-service/docker/Dockerfile services/board-service
docker push 212clab/wealist-board-service:v1

# chat-service
docker build -t 212clab/wealist-chat-service:v1 -f services/chat-service/docker/Dockerfile services/chat-service
docker push 212clab/wealist-chat-service:v1

# user-service
docker build -t 212clab/wealist-user-service:v1 -f services/user-service/docker/Dockerfile services/user-service
docker push 212clab/wealist-user-service:v1

# noti-service
docker build -t 212clab/wealist-noti-service:v1 -f services/noti-service/docker/Dockerfile services/noti-service
docker push 212clab/wealist-noti-service:v1

# frontend
docker build -t 212clab/wealist-frontend:v1 -f services/frontend/Dockerfile services/frontend
docker push 212clab/wealist-frontend:v1
