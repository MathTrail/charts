{{/*
=======================================================================
  mathtrail-service-lib :: _rbac.tpl
  Role + RoleBinding for the init-container that checks
  Migration Job status via the Kubernetes API.
=======================================================================
*/}}

{{- define "mathtrail-service-lib.rbac" -}}
{{- $v := include "mathtrail-service-lib.mergedValues" . | fromYaml }}
{{- if and $v.migration.enabled $v.serviceAccount.create }}
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ include "mathtrail-service-lib.fullname" . }}-migration-watcher
  labels:
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
rules:
  - apiGroups: ["batch"]
    resources: ["jobs"]
    verbs: ["get", "watch", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ include "mathtrail-service-lib.fullname" . }}-migration-watcher
  labels:
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: {{ include "mathtrail-service-lib.fullname" . }}-migration-watcher
subjects:
  - kind: ServiceAccount
    name: {{ include "mathtrail-service-lib.serviceAccountName" . }}
    namespace: {{ .Release.Namespace }}
{{- end }}
{{- end -}}
