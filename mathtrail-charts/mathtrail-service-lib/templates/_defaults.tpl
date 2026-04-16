{{/*
=======================================================================
  mathtrail-service-lib :: _defaults.tpl
  Centralized default values for the library chart.
  Library chart values.yaml does NOT merge into parent chart,
  so defaults are defined here and merged at render time.
=======================================================================
*/}}

{{- define "mathtrail-service-lib.defaults" -}}
replicaCount: 1
image:
  repository: ""
  tag: ""
  pullPolicy: IfNotPresent
serviceAccount:
  create: true
  automount: true
  name: ""
podSecurityContext:
  runAsNonRoot: true
securityContext:
  readOnlyRootFilesystem: true
  runAsNonRoot: true
service:
  type: ClusterIP
  port: 8080
probes:
  startup:
    path: /health/startup
    initialDelaySeconds: 0
    periodSeconds: 5
    failureThreshold: 30
    timeoutSeconds: 3
  liveness:
    path: /health/liveness
    initialDelaySeconds: 0
    periodSeconds: 10
    failureThreshold: 3
    timeoutSeconds: 3
  readiness:
    path: /health/ready
    initialDelaySeconds: 0
    periodSeconds: 10
    failureThreshold: 3
    timeoutSeconds: 3
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
migration:
  enabled: false
  command:
    - "./migrate"
  backoffLimit: 3
  ttlSecondsAfterFinished: 300
  restartPolicy: OnFailure
  waitImage: "bitnami/kubectl:latest"
  waitTimeout: "120s"
  resources:
    requests:
      cpu: "50m"
      memory: "64Mi"
    limits:
      cpu: "200m"
      memory: "256Mi"
configMap:
  enabled: false
preStopDelaySec: 5
terminationGracePeriodSeconds: 30
defaultAntiAffinity:
  enabled: true
autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
dashboard:
  enabled: false
  folder: "MathTrail"
vaultDbConfig:
  enabled: false
  image: "alpine:3.21"
  waitImage: "busybox:1.36"
  vaultAddr: "http://vault.vault.svc.cluster.local:8200"
  vaultRole: "db-admin-role"
  pgSecretName: "postgres-postgresql"
  pgSecretKey: "postgres-password"
  pgHost: "postgres-postgresql.mathtrail.svc.cluster.local"
  pgPort: "5432"
  pgUsername: "postgres"
  connectionName: ""
  pgDatabase: ""
  roleName: ""
  defaultTtl: "1h"
  maxTtl: "24h"
  backoffLimit: 3
  ttlSecondsAfterFinished: 300
  resources:
    requests:
      cpu: "50m"
      memory: "64Mi"
    limits:
      cpu: "200m"
      memory: "128Mi"
vso:
  enabled: false
  vaultRole: ""    # defaults to .fullname at template render time
  dbRole: ""       # defaults to "<fullname>-role" at template render time
  secretName: ""   # defaults to "<fullname>-db-secret" at template render time
{{- end -}}

{{/*
Merge library defaults with user-provided .Values.
Converts .Values via toYaml/fromYaml to avoid chartutil.Values type issues
with merge functions in Helm < 3.13.
*/}}
{{- define "mathtrail-service-lib.mergedValues" -}}
{{- $defaults := include "mathtrail-service-lib.defaults" . | fromYaml -}}
{{- $userVals := .Values | toYaml | fromYaml -}}
{{- mustMergeOverwrite $defaults $userVals | toYaml -}}
{{- end -}}
