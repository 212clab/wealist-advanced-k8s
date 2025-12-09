# Infrastructure Components

Wealist 프로젝트의 Kubernetes 인프라 구성 요소에 대한 설명입니다.

## 개요

```
infrastructure/
├── base/
│   ├── postgres/       # 데이터베이스
│   ├── redis/          # 캐시/세션 저장소
│   ├── coturn/         # TURN/STUN 서버 (WebRTC)
│   ├── livekit/        # 실시간 비디오 서버
│   └── monitoring/     # 모니터링 스택
│       ├── prometheus/
│       ├── grafana/
│       └── loki/
└── overlays/
    ├── local/          # 로컬 개발 환경
    └── eks/            # AWS EKS 프로덕션 환경
```

---

## 데이터 저장소

### PostgreSQL
| 항목 | 내용 |
|------|------|
| **용도** | 관계형 데이터베이스 |
| **저장 데이터** | 사용자, 게시글, 프로젝트, 채팅 기록 등 |
| **포트** | 5432 |
| **이미지** | `postgres:15-alpine` |

각 서비스별로 별도의 데이터베이스가 생성됩니다:
- `user_db` - 사용자 정보
- `auth_db` - 인증 정보
- `board_db` - 게시판/프로젝트
- `chat_db` - 채팅
- `noti_db` - 알림

### Redis
| 항목 | 내용 |
|------|------|
| **용도** | 인메모리 캐시 및 세션 저장소 |
| **저장 데이터** | 로그인 세션, 캐시, 실시간 데이터 |
| **포트** | 6379 |
| **이미지** | `redis:7-alpine` |

---

## 화상통화 인프라 (WebRTC)

### LiveKit
| 항목 | 내용 |
|------|------|
| **용도** | 실시간 비디오/오디오 서버 |
| **역할** | Zoom, Google Meet 같은 화상회의 기능 제공 |
| **포트** | 7880 (HTTP), 7881 (RTC) |
| **이미지** | `livekit/livekit-server` |

**특징:**
- WebRTC 기반 실시간 통신
- 다자간 화상회의 지원
- 화면 공유 기능
- video-service가 LiveKit API를 통해 방 생성/관리

### Coturn (TURN/STUN Server)
| 항목 | 내용 |
|------|------|
| **용도** | NAT/방화벽 우회를 위한 중계 서버 |
| **역할** | 네트워크 환경에 관계없이 화상통화 연결 보장 |
| **포트** | 3478 (TURN), 5349 (TURNS) |
| **이미지** | `coturn/coturn` |

**왜 필요한가?**
```
문제: 대부분의 사용자는 NAT/방화벽 뒤에 있어서 직접 P2P 연결 불가
해결: Coturn이 중간에서 트래픽을 중계 (Relay)

[사용자 A] ←→ [Coturn] ←→ [사용자 B]
   (집)        (서버)       (회사)
```

**STUN vs TURN:**
- **STUN**: 내 공인 IP 확인 (가벼움, 직접 연결 시도)
- **TURN**: 트래픽 중계 (무거움, 직접 연결 실패 시 사용)

---

## 화상통화 전체 흐름

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Frontend  │────▶│video-service│────▶│   LiveKit   │
│  (React)    │     │   (Go API)  │     │   Server    │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                    ┌──────────────────────────┼──────────────────────────┐
                    │                          │                          │
                    ▼                          ▼                          ▼
             ┌─────────────┐           ┌─────────────┐           ┌─────────────┐
             │  사용자 A   │◀─────────▶│   Coturn    │◀─────────▶│  사용자 B   │
             │  (브라우저) │           │   (중계)    │           │  (브라우저) │
             └─────────────┘           └─────────────┘           └─────────────┘
```

1. **방 생성**: Frontend → video-service API 호출
2. **토큰 발급**: video-service → LiveKit에서 참가 토큰 생성
3. **연결 시도**: 브라우저가 LiveKit 서버에 WebRTC 연결
4. **NAT 우회**: 직접 연결 실패 시 Coturn을 통해 중계

---

## 모니터링 스택

### Prometheus
| 항목 | 내용 |
|------|------|
| **용도** | 메트릭 수집 및 저장 |
| **수집 대상** | CPU, 메모리, 요청 수, 응답 시간 등 |
| **포트** | 9090 |

### Grafana
| 항목 | 내용 |
|------|------|
| **용도** | 메트릭 시각화 대시보드 |
| **데이터 소스** | Prometheus, Loki |
| **포트** | 3000 |

### Loki
| 항목 | 내용 |
|------|------|
| **용도** | 로그 수집 및 검색 |
| **수집 대상** | 각 서비스의 애플리케이션 로그 |
| **포트** | 3100 |

---

## 환경별 구성

### Local (Kind)
```bash
kubectl apply -k infrastructure/overlays/local
```
- Namespace: `wealist-local`
- 모든 컴포넌트가 클러스터 내부에서 실행
- 개발/테스트용 경량 설정

### EKS (Production)
```bash
kubectl apply -k infrastructure/overlays/eks
```
- Namespace: `wealist-prod`
- AWS RDS (PostgreSQL) 사용 가능
- AWS ElastiCache (Redis) 사용 가능
- 프로덕션용 리소스 설정

---

## 컴포넌트 비교 요약

| 컴포넌트 | 유형 | 용도 | 비유 |
|----------|------|------|------|
| PostgreSQL | 데이터 저장 | 영구 데이터 보관 | 창고 |
| Redis | 캐시 | 빠른 임시 데이터 | 메모장 |
| LiveKit | 미디어 서버 | 화상통화 처리 | 방송국 |
| Coturn | 네트워크 중계 | 방화벽 우회 | 우체부 |
| Prometheus | 모니터링 | 수치 데이터 수집 | 계기판 |
| Grafana | 시각화 | 대시보드 표시 | TV 화면 |
| Loki | 로그 관리 | 텍스트 로그 수집 | 일기장 |
