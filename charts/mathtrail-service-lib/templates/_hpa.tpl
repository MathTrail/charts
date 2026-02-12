{{/*
=======================================================================
  mathtrail-service-lib :: _hpa.tpl
  HorizontalPodAutoscaler for microservice autoscaling.
=======================================================================
*/}}

{{- define "mathtrail-service-lib.hpa" -}}
{{- $v := include "mathtrail-service-lib.mergedValues" . | fromYaml }}
{{- if $v.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "mathtrail-service-lib.fullname" . }}
  labels:
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "mathtrail-service-lib.fullname" . }}
  minReplicas: {{ $v.autoscaling.minReplicas }}
  maxReplicas: {{ $v.autoscaling.maxReplicas }}
  metrics:
    {{- if $v.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ $v.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if $v.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ $v.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
{{- end }}
{{- end -}}
