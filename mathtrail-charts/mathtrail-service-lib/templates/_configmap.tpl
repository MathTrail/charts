{{/*
=======================================================================
  mathtrail-service-lib :: _configmap.tpl
  ConfigMap for common microservice environment settings.
=======================================================================
*/}}

{{- define "mathtrail-service-lib.configMap" -}}
{{- $v := include "mathtrail-service-lib.mergedValues" . | fromYaml }}
{{- if $v.configMap.enabled }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "mathtrail-service-lib.fullname" . }}-env
  labels:
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
data:
  {{- range $key, $value := $v.configMap.data }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
{{- end }}
{{- end -}}
