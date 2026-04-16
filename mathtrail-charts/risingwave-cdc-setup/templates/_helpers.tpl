{{/*
=======================================================================
  risingwave-cdc-setup :: _helpers.tpl
=======================================================================
*/}}

{{- define "risingwave-cdc-setup.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "risingwave-cdc-setup.fullname" -}}
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

{{- define "risingwave-cdc-setup.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "risingwave-cdc-setup.labels" -}}
helm.sh/chart: {{ include "risingwave-cdc-setup.chart" . }}
{{ include "risingwave-cdc-setup.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: mathtrail
{{- end }}

{{- define "risingwave-cdc-setup.selectorLabels" -}}
app.kubernetes.io/name: {{ include "risingwave-cdc-setup.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
