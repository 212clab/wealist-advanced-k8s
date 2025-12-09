```
1. kind-config.yaml
   → 로컬에 K8s 클러스터 생성 (노드 몇 개, 포트 매핑 등)
   → "빈 서버 3대 준비했어!"

2. infrastructure/
   → PostgreSQL, Redis 같은 인프라 배포
   → "DB 설치했어!"

3. services/*/k8s/
   → 각 서비스(user, auth, board...) 배포
   → "앱 배포했어!"

4. argocd/
   → 위 2, 3번을 자동으로 배포/관리 (GitOps)
   → "Git 보고 자동으로 배포할게!"
```


# 1208(월) 일지
```
0. kind-config.yaml 만들고 
0-1. kind create cluster --name wealist --config kind-config.yaml

1. 로컬에서 ingress 규칙을 시행할 controller 설치(nginx ingress controller)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

1-1. kubectl get pods -n ingress-nginx 확인


2. ns 준비 
2-1. /infrastructure/base/namespace.yaml, 그리고 /infrastructure/base/kustomization.yaml 으로 기본 구성으로 가져갈 것들 정의
/overlays/local/namespace.yaml에 wealist-local ns 정의 


3. 로컬 배포 테스트
3-1. 생성될 자원 확인 kubectl kustomize infrastructure/overlays/local
3-2. 실제 배포 kubectl apply -k infrastructure/overlays/local
3-3. 확인 kubectl get ns


```


# 1209(화) 일지
```
4. 이미지를 빌드해서 docker-hub에 이미지를 넣고 그 이미지를 땡겨와서 배포하자(argoCD 대비)
4-1. docker login
4-2. ./docker/scripts/push_imgs.sh

5. infrastructure 배포
    # 먼저 뭐가 생성되는지 확인 (dry-run)
    kubectl kustomize infrastructure/overlays/local
    # 실제 배포
    kubectl apply -k infrastructure/overlays/local
    # 확인
    kubectl get all -n wealist-local

```

# 첨부터 한다면
```
Step 1. Kind 클러스터 생성
kind create cluster --name wealist --config kind-config.yaml

Step 2. Ingress Nginx Controller 설치
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# 설치 확인 (Running 될 때까지)
kubectl get pods -n ingress-nginx

Step 3. Infrastructure 배포
kubectl apply -k infrastructure/overlays/local

# postgres, redis Running 확인
kubectl get pods -n wealist-local

Step 4. 서비스들 배포
kubectl apply -k services/auth-service/k8s/overlays/local
kubectl apply -k services/user-service/k8s/overlays/local
kubectl apply -k services/board-service/k8s/overlays/local
kubectl apply -k services/chat-service/k8s/overlays/local
kubectl apply -k services/noti-service/k8s/overlays/local
kubectl apply -k services/frontend/k8s/overlays/local
kubectl apply -k services/storage-service/k8s/overlays/local
kubectl apply -k services/video-service/k8s/overlays/local


kind delete cluster --name wealist


```