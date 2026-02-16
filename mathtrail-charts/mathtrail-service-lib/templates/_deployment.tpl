{{/*
=======================================================================
  mathtrail-service-lib :: _deployment.tpl
  Main Deployment with:
    - Init Container waiting for migration completion
    - Dapr Sidecar integration
    - Mandatory probe contract (Startup/Liveness/Readiness)
    - Security Context
    - Resource Requests & Limits
    - Graceful Shutdown (preStop hook)
=======================================================================
*/}}

{{- define "mathtrail-service-lib.deployment" -}}
{{ include "mathtrail-service-lib.validateImage" . }}
{{- $v := include "mathtrail-service-lib.mergedValues" . | fromYaml }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "mathtrail-service-lib.fullname" . }}
  labels:
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
spec:
  {{- if not $v.autoscaling.enabled }}
  replicas: {{ $v.replicaCount }}
  {{- end }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  selector:
    matchLabels:
      {{- include "mathtrail-service-lib.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        {{- include "mathtrail-service-lib.daprAnnotations" . | nindent 8 }}
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "mathtrail-service-lib.labels" . | nindent 8 }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "mathtrail-service-lib.serviceAccountName" . }}
      terminationGracePeriodSeconds: {{ $v.terminationGracePeriodSeconds }}
      securityContext:
        runAsNonRoot: {{ $v.podSecurityContext.runAsNonRoot }}
        {{- with $v.podSecurityContext.fsGroup }}
        fsGroup: {{ . }}
        {{- end }}
        {{- with $v.podSecurityContext.runAsUser }}
        runAsUser: {{ . }}
        {{- end }}
        {{- with $v.podSecurityContext.runAsGroup }}
        runAsGroup: {{ . }}
        {{- end }}

      {{/* Init container: wait for migration completion */}}
      {{- if $v.migration.enabled }}
      initContainers:
        - name: wait-for-migration
          image: {{ $v.migration.waitImage }}
          command:
            - "/bin/sh"
            - "-c"
            - "kubectl wait --for=condition=complete job/{{ include "mathtrail-service-lib.fullname" . }}-migrate --timeout={{ $v.migration.waitTimeout }}"
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            runAsNonRoot: true
          resources:
            requests:
              cpu: "10m"
              memory: "32Mi"
            limits:
              cpu: "50m"
              memory: "64Mi"
      {{- end }}

      containers:
        - name: {{ .Chart.Name }}
          image: "{{ $v.image.repository }}:{{ $v.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ $v.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ $v.service.port }}
              protocol: TCP

          {{/* ---- Probe contract ---- */}}
          startupProbe:
            httpGet:
              path: {{ $v.probes.startup.path }}
              port: http
            initialDelaySeconds: {{ $v.probes.startup.initialDelaySeconds }}
            periodSeconds: {{ $v.probes.startup.periodSeconds }}
            failureThreshold: {{ $v.probes.startup.failureThreshold }}
            timeoutSeconds: {{ $v.probes.startup.timeoutSeconds }}

          livenessProbe:
            httpGet:
              path: {{ $v.probes.liveness.path }}
              port: http
            initialDelaySeconds: {{ $v.probes.liveness.initialDelaySeconds }}
            periodSeconds: {{ $v.probes.liveness.periodSeconds }}
            failureThreshold: {{ $v.probes.liveness.failureThreshold }}
            timeoutSeconds: {{ $v.probes.liveness.timeoutSeconds }}

          readinessProbe:
            httpGet:
              path: {{ $v.probes.readiness.path }}
              port: http
            initialDelaySeconds: {{ $v.probes.readiness.initialDelaySeconds }}
            periodSeconds: {{ $v.probes.readiness.periodSeconds }}
            failureThreshold: {{ $v.probes.readiness.failureThreshold }}
            timeoutSeconds: {{ $v.probes.readiness.timeoutSeconds }}

          {{/* ---- Resources ---- */}}
          resources:
            {{- toYaml $v.resources | nindent 12 }}

          {{/* ---- Container Security Context ---- */}}
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: {{ $v.securityContext.readOnlyRootFilesystem }}
            runAsNonRoot: {{ $v.securityContext.runAsNonRoot }}
            {{- with $v.securityContext.runAsUser }}
            runAsUser: {{ . }}
            {{- end }}
            capabilities:
              drop:
                - ALL

          {{/* ---- Environment variables ---- */}}
          env:
            - name: APP_NAME
              value: {{ include "mathtrail-service-lib.name" . }}
            - name: NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            {{- with .Values.env }}
            {{- toYaml . | nindent 12 }}
            {{- end }}

          {{- if or $v.configMap.enabled .Values.envFrom }}
          envFrom:
            {{- if $v.configMap.enabled }}
            - configMapRef:
                name: {{ include "mathtrail-service-lib.fullname" . }}-env
            {{- end }}
            {{- with .Values.envFrom }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- end }}

          {{/* ---- Graceful Shutdown ---- */}}
          lifecycle:
            preStop:
              exec:
                command:
                  - "/bin/sh"
                  - "-c"
                  - "sleep {{ $v.preStopDelaySec }}"

          {{- with .Values.volumeMounts }}
          volumeMounts:
            {{- toYaml . | nindent 12 }}
          {{- end }}

      {{- with .Values.volumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}

      {{/* ---- Affinity & Anti-Affinity ---- */}}
      {{- if or .Values.affinity $v.defaultAntiAffinity.enabled }}
      affinity:
        {{- if $v.defaultAntiAffinity.enabled }}
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    {{- include "mathtrail-service-lib.selectorLabels" . | nindent 20 }}
                topologyKey: kubernetes.io/hostname
        {{- end }}
        {{- with .Values.affinity }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- end }}

      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end -}}
