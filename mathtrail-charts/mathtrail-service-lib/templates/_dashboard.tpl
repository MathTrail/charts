{{/*
=======================================================================
  mathtrail-service-lib :: _dashboard.tpl
  Grafana dashboard ConfigMap provisioned via sidecar label.
=======================================================================
*/}}

{{- define "mathtrail-service-lib.grafanaDashboard" -}}
{{- $v := include "mathtrail-service-lib.mergedValues" . | fromYaml }}
{{- $fileName := printf "%s.json" (include "mathtrail-service-lib.name" .) }}
{{- $dashboardPath := printf "dashboards/%s" $fileName }}
{{- if and (dig "dashboard" "enabled" false $v) (.Files.Get $dashboardPath) }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "mathtrail-service-lib.fullname" . }}-grafana-dashboard
  labels:
    grafana_dashboard: "1"
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
  annotations:
    grafana_folder: {{ dig "dashboard" "folder" "MathTrail" $v | quote }}
data:
  {{ $fileName }}: |
    {{ .Files.Get $dashboardPath | nindent 4 }}
{{- end }}
{{- end -}}
