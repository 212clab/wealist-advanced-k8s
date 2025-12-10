import axios, { AxiosError, AxiosInstance, InternalAxiosRequestConfig } from 'axios';

// Runtime config type declaration (injected via config.js)
declare global {
  interface Window {
    __ENV__?: {
      API_BASE_URL?: string;
    };
  }
}

// 환경 변수 가져오기 (우선순위: runtime config > build-time env)
// - K8s ingress: window.__ENV__.API_BASE_URL = "" (빈 문자열 = 상대 경로)
// - Docker-compose: import.meta.env.VITE_API_BASE_URL = "http://localhost" (포트별 접근)
// - Production: 빌드 시 주입된 URL 사용

// K8s ingress 모드 감지: 명시적으로 빈 문자열이 설정된 경우
const isIngressMode = window.__ENV__?.API_BASE_URL === '';

// ingress 모드가 아닐 때만 폴백 적용
const INJECTED_API_BASE_URL = isIngressMode
  ? ''
  : window.__ENV__?.API_BASE_URL || import.meta.env.VITE_API_BASE_URL;

// ============================================================================
// 💡 [핵심 수정]: Context Path를 환경에 따라 조건부로 붙입니다.
// ============================================================================

// K8s ingress용 서비스 prefix 매핑
// ingress가 /svc/{service}/* 로 라우팅하고, rewrite로 prefix 제거
const getIngressServicePrefix = (path: string): string => {
  if (path?.includes('/api/auth')) return '/svc/auth';
  if (path?.includes('/api/users')) return '/svc/user';
  if (path?.includes('/api/workspaces')) return '/svc/user';
  if (path?.includes('/api/profiles')) return '/svc/user';
  if (path?.includes('/api/boards')) return '/svc/board/api';
  if (path?.includes('/api/chats')) return `/svc/chat${path}`;
  if (path?.includes('/api/notifications')) return '/svc/noti';
  if (path?.includes('/api/storage')) return '/svc/storage/api';
  if (path?.includes('/api/video')) return '/svc/video';
  return ''; // 매칭 안 되면 prefix 없이
};

const getApiBaseUrl = (path: string): string => {
  // 1. K8s ingress 모드: 서비스 prefix만 반환 (axios가 path를 붙임)
  // 예: getApiBaseUrl('/api/users') → '/svc/user'
  //     axios.get('/api/workspaces/all') → '/svc/user/api/workspaces/all'
  if (isIngressMode) {
    return getIngressServicePrefix(path);
  }

  // 2. 환경 변수 주입 확인 (Docker-compose 등)
  if (INJECTED_API_BASE_URL) {
    // 쉘 스크립트에서 VITE_API_BASE_URL='http://localhost'가 주입된 경우
    const isLocalDevelopment = INJECTED_API_BASE_URL.includes('localhost');

    if (isLocalDevelopment) {
      // 🔥 로컬 개발: 각 서비스별 포트 지정
      // auth-service: refresh 호출이 '/refresh'만 사용하므로 context path 포함
      if (path?.includes('/api/auth')) return `${INJECTED_API_BASE_URL}:8080/api/auth`; // auth-service
      // user-service: 요청이 full path 사용 (/api/users/*, /api/workspaces/*, /api/profiles/*)
      if (path?.includes('/api/users')) return `${INJECTED_API_BASE_URL}:8081`; // user-service
      if (path?.includes('/api/workspaces')) return `${INJECTED_API_BASE_URL}:8081`; // user-service (workspaces)
      if (path?.includes('/api/profiles')) return `${INJECTED_API_BASE_URL}:8081`; // user-service (profiles)
      if (path?.includes('/api/boards')) return `${INJECTED_API_BASE_URL}:8000/api`;
      if (path?.includes('/api/chats')) return `${INJECTED_API_BASE_URL}:8001${path}`;
      if (path?.includes('/api/notifications')) return `${INJECTED_API_BASE_URL}:8002`;
      if (path?.includes('/api/storage')) return `${INJECTED_API_BASE_URL}:8003/api`; // storage-service (base path only)
      if (path?.includes('/api/video')) return `${INJECTED_API_BASE_URL}:8004`;
    }

    return `${INJECTED_API_BASE_URL}${path}`;
  }

  // 환경 변수가 없을 경우 (Fallback, CI/CD 실패 대비)
  return `https://api.wealist.co.kr${path}`;
};

export const AUTH_SERVICE_API_URL = getApiBaseUrl('/api/auth'); // auth-service (토큰 관리)
export const USER_REPO_API_URL = getApiBaseUrl('/api/users');
export const USER_SERVICE_API_URL = getApiBaseUrl('/api/users'); // 💡 user-service base URL (프로필 API용)
export const BOARD_SERVICE_API_URL = getApiBaseUrl('/api/boards/api');
export const CHAT_SERVICE_API_URL = getApiBaseUrl('/api/chats');
export const NOTI_SERVICE_API_URL = getApiBaseUrl('/api/notifications');
export const STORAGE_SERVICE_API_URL = getApiBaseUrl('/api/storage'); // storage-service (Google Drive like)
export const VIDEO_SERVICE_API_URL = getApiBaseUrl('/api/video'); // video-service

// ============================================================================
// Axios 인스턴스 생성
// ============================================================================

/**
 * Auth Service API (Java)를 위한 Axios 인스턴스 - 토큰 관리 전용
 */
export const authServiceClient = axios.create({
  baseURL: AUTH_SERVICE_API_URL,
  headers: { 'Content-Type': 'application/json' },
  withCredentials: true,
});

/**
 * User Repo API (Java)를 위한 Axios 인스턴스
 */
export const userRepoClient = axios.create({
  baseURL: USER_REPO_API_URL,
  headers: { 'Content-Type': 'application/json' },
  withCredentials: true,
});

/**
 * Board Service API (Go)를 위한 Axios 인스턴스
 */
export const boardServiceClient = axios.create({
  baseURL: BOARD_SERVICE_API_URL,
  headers: { 'Content-Type': 'application/json' },
  withCredentials: true,
});

/**
 * Chat Service API (Go)를 위한 Axios 인스턴스
 */
export const chatServiceClient = axios.create({
  baseURL: CHAT_SERVICE_API_URL,
  headers: { 'Content-Type': 'application/json' },
  withCredentials: true,
});

/**
 * Notification Service API (Go)를 위한 Axios 인스턴스
 */
export const notiServiceClient = axios.create({
  baseURL: NOTI_SERVICE_API_URL,
  headers: { 'Content-Type': 'application/json' },
  withCredentials: true,
});

/**
 * Storage Service API (Go)를 위한 Axios 인스턴스 - Google Drive like storage
 */
export const storageServiceClient = axios.create({
  baseURL: STORAGE_SERVICE_API_URL,
  headers: { 'Content-Type': 'application/json' },
  withCredentials: true,
});

/**
 * Video Service API (Go)를 위한 Axios 인스턴스 - 화상통화
 */
export const videoServiceClient = axios.create({
  baseURL: VIDEO_SERVICE_API_URL,
  headers: { 'Content-Type': 'application/json' },
  withCredentials: true,
});

// ============================================================================
// 인증 갱신 헬퍼 함수 (기존 코드 유지)
// ============================================================================

let isRefreshing = false;
let failedQueue: Array<{
  resolve: (value?: unknown) => void;
  reject: (reason?: unknown) => void;
}> = [];

const processQueue = (error: Error | null, token: string | null = null) => {
  failedQueue.forEach((prom) => {
    if (error) {
      prom.reject(error);
    } else {
      prom.resolve(token);
    }
  });
  failedQueue = [];
};

const performLogout = () => {
  localStorage.removeItem('accessToken');
  localStorage.removeItem('refreshToken');
  localStorage.removeItem('nickName');
  localStorage.removeItem('userEmail');
  window.location.href = '/';
};

const refreshAccessToken = async (): Promise<string> => {
  const refreshToken = localStorage.getItem('refreshToken');
  if (!refreshToken) {
    console.warn('⚠️ Refresh token not found. Logging out...');
    performLogout();
    throw new Error('No refresh token available');
  }

  try {
    // auth-service의 /api/auth/refresh 엔드포인트 호출
    const response = await axios.post(`${AUTH_SERVICE_API_URL}/refresh`, {
      refreshToken,
    });

    const { accessToken, refreshToken: newRefreshToken } = response.data;

    localStorage.setItem('accessToken', accessToken);
    if (newRefreshToken) {
      localStorage.setItem('refreshToken', newRefreshToken);
    }

    return accessToken;
  } catch (error) {
    localStorage.removeItem('accessToken');
    localStorage.removeItem('refreshToken');
    localStorage.removeItem('nickName');
    localStorage.removeItem('userEmail');
    window.location.href = '/';
    throw error;
  }
};

// ============================================================================
// 인터셉터 설정
// ============================================================================

const setupRequestInterceptor = (client: AxiosInstance) => {
  client.interceptors.request.use(
    (config) => {
      const accessToken = localStorage.getItem('accessToken');
      if (accessToken && !config.headers.Authorization) {
        config.headers.Authorization = `Bearer ${accessToken}`;
      }
      return config;
    },
    (error) => {
      return Promise.reject(error);
    },
  );
};

const setupUnifiedResponseInterceptor = (client: AxiosInstance) => {
  client.interceptors.response.use(
    (response) => response,
    async (error: AxiosError) => {
      const originalRequest = error.config as InternalAxiosRequestConfig & {
        _retry?: boolean;
        retryCount?: number;
      };
      const status = error.response?.status;

      if (status === 401 && !originalRequest._retry) {
        if (isRefreshing) {
          return new Promise((resolve, reject) => {
            failedQueue.push({ resolve, reject });
          })
            .then((token) => {
              originalRequest.headers.Authorization = `Bearer ${token}`;
              return client(originalRequest);
            })
            .catch((err) => {
              return Promise.reject(err);
            });
        }

        originalRequest._retry = true;
        isRefreshing = true;

        try {
          const newAccessToken = await refreshAccessToken();
          processQueue(null, newAccessToken);
          originalRequest.headers.Authorization = `Bearer ${newAccessToken}`;
          return client(originalRequest);
        } catch (refreshError) {
          processQueue(refreshError as Error, null);
          return Promise.reject(refreshError);
        } finally {
          isRefreshing = false;
        }
      }

      if (status && status >= 400 && status < 599) {
        return Promise.reject(error);
      }

      if (!status && error.code !== 'ERR_CANCELED') {
        originalRequest.retryCount = originalRequest.retryCount || 0;

        if (originalRequest.retryCount >= 3) {
          console.error(`[Axios Interceptor] 최대 재시도 횟수 초과: ${originalRequest.url}`);
          return Promise.reject(error);
        }

        originalRequest.retryCount += 1;
        const delay = new Promise((resolve) => setTimeout(resolve, 1000));
        console.warn(
          `[Axios Interceptor] 재시도 중 (${originalRequest.retryCount}회): ${originalRequest.url}`,
        );
        await delay;
        return client(originalRequest);
      }
    },
  );
};

// 인터셉터 적용
setupRequestInterceptor(authServiceClient);
setupRequestInterceptor(userRepoClient);
setupRequestInterceptor(boardServiceClient);
setupRequestInterceptor(chatServiceClient);
setupRequestInterceptor(notiServiceClient);
setupRequestInterceptor(storageServiceClient);
setupRequestInterceptor(videoServiceClient);

setupUnifiedResponseInterceptor(authServiceClient);
setupUnifiedResponseInterceptor(userRepoClient);
setupUnifiedResponseInterceptor(boardServiceClient);
setupUnifiedResponseInterceptor(chatServiceClient);
setupUnifiedResponseInterceptor(notiServiceClient);
setupUnifiedResponseInterceptor(storageServiceClient);
setupUnifiedResponseInterceptor(videoServiceClient);

export const getAuthHeaders = (token: string) => ({
  Authorization: `Bearer ${token}`,
  Accept: 'application/json',
});

// ============================================================================
// WebSocket / SSE URL 생성 헬퍼 (중앙 집중 관리)
// ============================================================================

/**
 * 환경 감지 헬퍼 (export for external use)
 */
export const getIsIngressMode = (): boolean => isIngressMode;
export const getIsLocalDevelopment = (): boolean => {
  return INJECTED_API_BASE_URL?.includes('localhost') ?? false;
};

/**
 * WebSocket 프로토콜 결정
 */
const getWebSocketProtocol = (baseUrl?: string): 'wss:' | 'ws:' => {
  if (baseUrl?.startsWith('https')) return 'wss:';
  if (window.location.protocol === 'https:') return 'wss:';
  return 'ws:';
};

/**
 * Chat WebSocket URL 생성
 * @param chatId - 채팅방 ID
 * @param token - 액세스 토큰
 */
export const getChatWebSocketUrl = (chatId: string, token: string): string => {
  const encodedToken = encodeURIComponent(token);

  // K8s ingress 모드
  if (isIngressMode) {
    const protocol = getWebSocketProtocol();
    return `${protocol}//${window.location.host}/svc/chat/api/chats/ws/${chatId}?token=${encodedToken}`;
  }

  // Docker-compose (로컬 개발)
  if (INJECTED_API_BASE_URL?.includes('localhost')) {
    return `ws://localhost:8001/api/chats/ws/${chatId}?token=${encodedToken}`;
  }

  // 운영 환경 (ALB 라우팅)
  if (INJECTED_API_BASE_URL) {
    const protocol = getWebSocketProtocol(INJECTED_API_BASE_URL);
    const host = INJECTED_API_BASE_URL.replace(/^https?:\/\//, '');
    return `${protocol}//${host}/api/chats/ws/${chatId}?token=${encodedToken}`;
  }

  // Fallback
  const host = window.location.host;
  if (host.includes('localhost') || host.includes('127.0.0.1')) {
    return `ws://localhost:8001/api/chats/ws/${chatId}?token=${encodedToken}`;
  }

  return `wss://api.wealist.co.kr/api/chats/ws/${chatId}?token=${encodedToken}`;
};

/**
 * Presence WebSocket URL 생성 (온라인 상태)
 * @param token - 액세스 토큰
 */
export const getPresenceWebSocketUrl = (token: string): string => {
  const encodedToken = encodeURIComponent(token);

  // K8s ingress 모드
  if (isIngressMode) {
    const protocol = getWebSocketProtocol();
    return `${protocol}//${window.location.host}/svc/chat/api/chats/ws/presence?token=${encodedToken}`;
  }

  // Docker-compose (로컬 개발)
  if (INJECTED_API_BASE_URL?.includes('localhost')) {
    return `ws://localhost:8001/api/chats/ws/presence?token=${encodedToken}`;
  }

  // 운영 환경 (ALB 라우팅)
  if (INJECTED_API_BASE_URL) {
    const protocol = getWebSocketProtocol(INJECTED_API_BASE_URL);
    const host = INJECTED_API_BASE_URL.replace(/^https?:\/\//, '');
    return `${protocol}//${host}/api/chats/ws/presence?token=${encodedToken}`;
  }

  // Fallback
  const host = window.location.host;
  if (host.includes('localhost') || host.includes('127.0.0.1')) {
    return `ws://localhost:8001/api/chats/ws/presence?token=${encodedToken}`;
  }

  return `wss://api.wealist.co.kr/api/chats/ws/presence?token=${encodedToken}`;
};

/**
 * Board WebSocket URL 생성
 * @param projectId - 프로젝트 ID
 * @param token - 액세스 토큰
 */
export const getBoardWebSocketUrl = (projectId: string, token: string): string => {
  const encodedToken = encodeURIComponent(token);

  // K8s ingress 모드
  if (isIngressMode) {
    const protocol = getWebSocketProtocol();
    return `${protocol}//${window.location.host}/svc/board/api/boards/ws/project/${projectId}?token=${encodedToken}`;
  }

  // Docker-compose (로컬 개발)
  if (INJECTED_API_BASE_URL?.includes('localhost')) {
    return `ws://localhost:8000/api/boards/ws/project/${projectId}?token=${encodedToken}`;
  }

  // 운영 환경 (ALB 라우팅)
  if (INJECTED_API_BASE_URL) {
    const protocol = getWebSocketProtocol(INJECTED_API_BASE_URL);
    const host = INJECTED_API_BASE_URL.replace(/^https?:\/\//, '');
    return `${protocol}//${host}/api/boards/ws/project/${projectId}?token=${encodedToken}`;
  }

  // Fallback
  const host = window.location.host;
  if (host.includes('localhost') || host.includes('127.0.0.1')) {
    return `ws://localhost:8000/api/boards/ws/project/${projectId}?token=${encodedToken}`;
  }

  return `wss://api.wealist.co.kr/api/boards/ws/project/${projectId}?token=${encodedToken}`;
};

/**
 * Notification SSE Stream URL 생성
 * @param token - 액세스 토큰 (optional, 없으면 localStorage에서 가져옴)
 */
export const getNotificationSSEUrl = (token?: string): string => {
  const accessToken = token || localStorage.getItem('accessToken') || '';
  const encodedToken = encodeURIComponent(accessToken);

  // K8s ingress 모드
  if (isIngressMode) {
    return `${window.location.origin}/svc/noti/api/notifications/stream?token=${encodedToken}`;
  }

  // Docker-compose (로컬 개발)
  if (INJECTED_API_BASE_URL?.includes('localhost')) {
    return `http://localhost:8002/api/notifications/stream?token=${encodedToken}`;
  }

  // 운영 환경 또는 Fallback
  return `${NOTI_SERVICE_API_URL}/api/notifications/stream?token=${encodedToken}`;
};
