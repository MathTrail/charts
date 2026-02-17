{{/*
=======================================================================
  mathtrail-service-lib :: _job.tpl
  Migration Job template — runs BEFORE the main deployment via Helm Hooks.
  Ensures the DB schema is updated before the new code version starts.
=======================================================================
*/}}

{{- define "mathtrail-service-lib.migrationJob" -}}
{{- $v := include "mathtrail-service-lib.mergedValues" . | fromYaml }}
{{- if $v.migration.enabled }}
{{ include "mathtrail-service-lib.validateImage" . }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "mathtrail-service-lib.fullname" . }}-migrate
  labels:
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "5"
    "helm.sh/hook-delete-policy": before-hook-creation
spec:
  backoffLimit: {{ $v.migration.backoffLimit }}
  ttlSecondsAfterFinished: {{ $v.migration.ttlSecondsAfterFinished }}
  template:
    metadata:
      labels:
        {{- include "mathtrail-service-lib.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/component: migration
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      securityContext:
        runAsNonRoot: {{ $v.podSecurityContext.runAsNonRoot }}
        {{- with $v.podSecurityContext.fsGroup }}
        fsGroup: {{ . }}
        {{- end }}
      containers:
        - name: migrate
          image: "{{ $v.image.repository }}:{{ $v.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ $v.image.pullPolicy }}
          command:
            {{- toYaml $v.migration.command | nindent 12 }}
          {{- with $v.migration.args }}
          args:
            {{- toYaml . | nindent 12 }}
          {{- end }}

          {{/* ---- Environment variables ---- */}}
          {{/* Migration inherits env from main deployment by default */}}
          {{- if or .Values.env $v.migration.env }}
          env:
            {{/* First: base env from deployment (if specified) */}}
            {{- with .Values.env }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
            {{/* Second: migration-specific env (can override base) */}}
            {{- with $v.migration.env }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- end }}

          {{/* ---- Environment From (ConfigMap, Secrets) ---- */}}
          {{- if or $v.configMap.enabled .Values.envFrom $v.migration.envFrom }}
          envFrom:
            {{- if $v.configMap.enabled }}
            - configMapRef:
                name: {{ include "mathtrail-service-lib.fullname" . }}-env
            {{- end }}
            {{- with .Values.envFrom }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
            {{- with $v.migration.envFrom }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- end }}

          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: {{ $v.securityContext.readOnlyRootFilesystem }}
            runAsNonRoot: {{ $v.securityContext.runAsNonRoot }}
          resources:
            {{- toYaml $v.migration.resources | nindent 12 }}
          {{- with .Values.volumeMounts }}
          volumeMounts:
            {{- toYaml . | nindent 12 }}
          {{- end }}
      {{- with .Values.volumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      restartPolicy: {{ $v.migration.restartPolicy }}
{{- end }}
{{- end -}}
