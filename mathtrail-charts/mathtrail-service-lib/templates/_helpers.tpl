{{/*
=======================================================================
  mathtrail-service-lib :: _helpers.tpl
  Common helper templates for the library chart.
=======================================================================
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "mathtrail-service-lib.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this
(by the DNS naming spec). If release name contains chart name it will be used
as a full name.
*/}}
{{- define "mathtrail-service-lib.fullname" -}}
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
{{- define "mathtrail-service-lib.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mathtrail-service-lib.labels" -}}
helm.sh/chart: {{ include "mathtrail-service-lib.chart" . }}
{{ include "mathtrail-service-lib.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: mathtrail
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mathtrail-service-lib.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mathtrail-service-lib.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use.
*/}}
{{- define "mathtrail-service-lib.serviceAccountName" -}}
{{- $v := include "mathtrail-service-lib.mergedValues" . | fromYaml }}
{{- if $v.serviceAccount.create }}
{{- default (include "mathtrail-service-lib.fullname" .) $v.serviceAccount.name }}
{{- else }}
{{- default "default" $v.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Dapr annotations — always injected when dapr.enabled is true.
*/}}
{{- define "mathtrail-service-lib.daprAnnotations" -}}
{{- $v := include "mathtrail-service-lib.mergedValues" . | fromYaml }}
{{- if $v.dapr.enabled }}
dapr.io/enabled: "true"
dapr.io/app-id: {{ $v.dapr.appId | default (include "mathtrail-service-lib.fullname" .) }}
dapr.io/app-port: {{ $v.service.port | quote }}
{{- with $v.dapr.appProtocol }}
dapr.io/app-protocol: {{ . | quote }}
{{- end }}
{{- with $v.dapr.logLevel }}
dapr.io/log-level: {{ . | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Validate image configuration.
*/}}
{{- define "mathtrail-service-lib.validateImage" -}}
{{- $v := include "mathtrail-service-lib.mergedValues" . | fromYaml }}
{{- if not $v.image.repository }}
{{- fail "FATAL: .Values.image.repository must be specified." }}
{{- end }}
{{- if not $v.image.tag }}
{{- if not .Chart.AppVersion }}
{{- fail "FATAL: Either .Values.image.tag or .Chart.AppVersion must be set." }}
{{- end }}
{{- end }}
{{- end }}
