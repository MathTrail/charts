{{/*
=======================================================================
  mathtrail-service-lib :: _serviceaccount.tpl
  ServiceAccount + automatic RBAC for init-container (wait-for-migration).
=======================================================================
*/}}

{{- define "mathtrail-service-lib.serviceAccount" -}}
{{- $v := include "mathtrail-service-lib.mergedValues" . | fromYaml }}
{{- if $v.serviceAccount.create }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "mathtrail-service-lib.serviceAccountName" . }}
  labels:
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
  {{- with $v.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
automountServiceAccountToken: {{ $v.serviceAccount.automount }}
{{- end }}
{{- end -}}
