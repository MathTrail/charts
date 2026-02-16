{{/*
=======================================================================
  mathtrail-service-lib :: _service.tpl
  Service template for the microservice.
=======================================================================
*/}}

{{- define "mathtrail-service-lib.service" -}}
{{- $v := include "mathtrail-service-lib.mergedValues" . | fromYaml }}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "mathtrail-service-lib.fullname" . }}
  labels:
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
  {{- with $v.service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ $v.service.type }}
  ports:
    - port: {{ $v.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "mathtrail-service-lib.selectorLabels" . | nindent 4 }}
{{- end -}}
