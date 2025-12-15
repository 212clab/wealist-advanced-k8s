{{/*
=============================================================================
Wealist Helm Chart - Template Helpers
=============================================================================
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "wealist.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "wealist.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "wealist.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels for all resources
*/}}
{{- define "wealist.labels" -}}
helm.sh/chart: {{ include "wealist.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: wealist
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- with .Values.global.labels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels for a specific service
Usage: {{ include "wealist.selectorLabels" (dict "name" "auth-service" "context" .) }}
*/}}
{{- define "wealist.selectorLabels" -}}
app.kubernetes.io/name: {{ .name }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
Service labels combining common labels and selector labels
Usage: {{ include "wealist.serviceLabels" (dict "name" "auth-service" "context" .) }}
*/}}
{{- define "wealist.serviceLabels" -}}
{{ include "wealist.labels" .context }}
{{ include "wealist.selectorLabels" . }}
{{- end }}

{{/*
Create the name of the namespace
*/}}
{{- define "wealist.namespace" -}}
{{- .Values.global.namespace | default "wealist-dev" }}
{{- end }}

{{/*
Create image name with registry
Usage: {{ include "wealist.image" (dict "repository" "auth-service" "tag" "latest" "context" .) }}
*/}}
{{- define "wealist.image" -}}
{{- $registry := .context.Values.global.imageRegistry -}}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry .repository (.tag | default "latest") }}
{{- else }}
{{- printf "%s:%s" .repository (.tag | default "latest") }}
{{- end }}
{{- end }}

{{/*
Create database URL for a service
Usage: {{ include "wealist.databaseUrl" (dict "dbName" "wealist_auth_db" "user" "auth_service" "password" "password" "host" "postgres" "port" "5432") }}
*/}}
{{- define "wealist.databaseUrl" -}}
{{- printf "postgresql://%s:%s@%s:%s/%s?sslmode=disable" .user .password .host .port .dbName }}
{{- end }}

{{/*
Common environment variables for all services (service discovery)
*/}}
{{- define "wealist.commonEnv" -}}
- name: ENV
  value: {{ .Values.global.environment | quote }}
- name: LOG_LEVEL
  value: {{ .Values.config.logLevel | quote }}
- name: AUTH_SERVICE_URL
  value: "http://auth-service:{{ .Values.authService.port }}"
- name: USER_SERVICE_URL
  value: "http://user-service:{{ .Values.userService.port }}"
- name: BOARD_SERVICE_URL
  value: "http://board-service:{{ .Values.boardService.port }}"
- name: CHAT_SERVICE_URL
  value: "http://chat-service:{{ .Values.chatService.port }}"
- name: NOTI_SERVICE_URL
  value: "http://noti-service:{{ .Values.notiService.port }}"
- name: STORAGE_SERVICE_URL
  value: "http://storage-service:{{ .Values.storageService.port }}"
- name: VIDEO_SERVICE_URL
  value: "http://video-service:{{ .Values.videoService.port }}"
- name: LIVEKIT_WS_URL
  value: "wss://{{ .Values.global.domain.public }}/svc/livekit"
- name: POSTGRES_HOST
  value: {{ .Values.postgres.enabled | ternary "postgres" (.Values.postgres.externalHost | default "postgres") | quote }}
- name: POSTGRES_PORT
  value: {{ .Values.postgres.service.port | quote }}
- name: REDIS_HOST
  value: {{ .Values.redis.enabled | ternary "redis" (.Values.redis.externalHost | default "redis") | quote }}
- name: REDIS_PORT
  value: {{ .Values.redis.service.port | quote }}
- name: S3_ENDPOINT
  value: {{ .Values.config.s3.endpoint | quote }}
- name: S3_PUBLIC_ENDPOINT
  value: {{ .Values.config.s3.publicEndpoint | quote }}
- name: S3_BUCKET
  value: {{ .Values.config.s3.bucket | quote }}
- name: S3_REGION
  value: {{ .Values.config.s3.region | quote }}
- name: CORS_ORIGINS
  value: {{ .Values.config.corsOrigins | quote }}
- name: INTERNAL_API_KEY
  valueFrom:
    secretKeyRef:
      name: wealist-secrets
      key: INTERNAL_API_KEY
{{- end }}

{{/*
Common environment variables from secrets
*/}}
{{- define "wealist.secretEnv" -}}
- name: S3_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: wealist-secrets
      key: S3_ACCESS_KEY
- name: S3_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: wealist-secrets
      key: S3_SECRET_KEY
{{- end }}

{{/*
Standard liveness probe
Usage: {{ include "wealist.livenessProbe" .Values.authService.probes.liveness }}
*/}}
{{- define "wealist.livenessProbe" -}}
livenessProbe:
  httpGet:
    path: {{ .path }}
    port: {{ .port | default "http" }}
  initialDelaySeconds: {{ .initialDelaySeconds | default 10 }}
  periodSeconds: {{ .periodSeconds | default 30 }}
  timeoutSeconds: {{ .timeoutSeconds | default 3 }}
  failureThreshold: {{ .failureThreshold | default 3 }}
{{- end }}

{{/*
Standard readiness probe
Usage: {{ include "wealist.readinessProbe" .Values.authService.probes.readiness }}
*/}}
{{- define "wealist.readinessProbe" -}}
readinessProbe:
  httpGet:
    path: {{ .path }}
    port: {{ .port | default "http" }}
  initialDelaySeconds: {{ .initialDelaySeconds | default 5 }}
  periodSeconds: {{ .periodSeconds | default 10 }}
  timeoutSeconds: {{ .timeoutSeconds | default 3 }}
  failureThreshold: {{ .failureThreshold | default 3 }}
{{- end }}

{{/*
Standard resource limits
Usage: {{ include "wealist.resources" .Values.authService.resources }}
*/}}
{{- define "wealist.resources" -}}
resources:
  {{- toYaml . | nindent 2 }}
{{- end }}
