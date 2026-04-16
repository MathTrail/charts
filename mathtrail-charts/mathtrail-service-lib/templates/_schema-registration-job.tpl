{{/*
=======================================================================
  mathtrail-service-lib :: _schema-registration-job.tpl
  Schema Registration Job — registers Protobuf schemas consumed/produced
  by this service into Apicurio Registry before the Deployment rolls.

  Uses the Confluent compat v7 API so subject names match exactly what
  RisingWave uses in FORMAT PLAIN ENCODE PROTOBUF.

  Subject naming: {package}.{MessageName} — e.g. students.v1.StudentOnboardingReady
  This matches RecordNameStrategy and avoids the default-{artifactId} prefix.

  Schemas must be self-contained (no import directives, string types throughout).
  If a schema requires imports, this Job must be extended to submit references:
    POST /apis/ccompat/v7/subjects/{subject}/versions with "references": [...]

  Apicurio may run in ephemeral mode (schemas lost on restart).
  Both ConfigMap and Job are pre-install/pre-upgrade hooks so the schema is
  registered before the app starts consuming events.

  Within the same hookWeight, Helm applies ConfigMap before Job (alphabetical
  Kind ordering) — no separate weight offset is needed.
=======================================================================
*/}}

{{- define "mathtrail-service-lib.schemaRegistrationJob" -}}
{{- $v := include "mathtrail-service-lib.mergedValues" . | fromYaml }}
{{- if $v.schemaRegistration.enabled }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "mathtrail-service-lib.fullname" . }}-schema-protos
  labels:
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
    app.kubernetes.io/component: schema-registration
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": {{ $v.schemaRegistration.hookWeight | quote }}
    "helm.sh/hook-delete-policy": before-hook-creation
data:
{{- range $v.schemaRegistration.schemas }}
  # Source: contracts/proto/{{ .subject | replace "." "/" }}.proto
  {{ .subject }}.proto: |
{{ .proto | indent 4 -}}
{{- end }}
---
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "mathtrail-service-lib.fullname" . }}-schema-registration
  labels:
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
    app.kubernetes.io/component: schema-registration
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": {{ $v.schemaRegistration.hookWeight | quote }}
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  backoffLimit: {{ $v.schemaRegistration.backoffLimit }}
  ttlSecondsAfterFinished: {{ $v.schemaRegistration.ttlSecondsAfterFinished }}
  template:
    metadata:
      labels:
        {{- include "mathtrail-service-lib.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/component: schema-registration
    spec:
      restartPolicy: {{ $v.schemaRegistration.restartPolicy }}
      initContainers:
        # Wait for Apicurio to be ready before attempting registration.
        - name: wait-apicurio
          image: curlimages/curl:8.7.1
          command:
            - sh
            - -c
            - |
              echo "Waiting for Apicurio Registry..."
              i=0
              until curl -sf "${APICURIO_URL}/apis/registry/v3/system/info" >/dev/null; do
                i=$((i+1))
                if [ "$i" -ge 20 ]; then
                  echo "Apicurio not ready after 60s, giving up." >&2
                  exit 1
                fi
                echo "  not ready, retrying in 3s... ($i/20)"
                sleep 3
              done
              echo "Apicurio is ready."
          env:
            - name: APICURIO_URL
              value: {{ $v.schemaRegistration.apicurioUrl | quote }}
          securityContext:
            allowPrivilegeEscalation: false
            runAsNonRoot: true
            runAsUser: 100  # curlimages/curl uses non-numeric 'curl_user' (UID 100); numeric UID required for runAsNonRoot verification
      containers:
        - name: register-schemas
          # alpine: apk adds curl + jq at runtime.
          # jq --rawfile safely escapes multiline .proto content into JSON
          # without manual quoting — avoids escaping "minefield".
          image: alpine:3.20
          command:
            - sh
            - -c
            - |
              set -e
              apk add --no-cache curl jq >/dev/null 2>&1

              # register_proto_schema: idempotent registration via Confluent compat v7 API.
              # HTTP 200 = registered, 409 = already exists — both are success.
              register_proto_schema() {
                local subject="$1"
                local proto_file="$2"
                echo "Registering subject: $subject"
                local body
                body=$(jq -n --rawfile schema "$proto_file" \
                  '{"schemaType": "PROTOBUF", "schema": $schema}')
                local http_code
                http_code=$(curl -s -o /tmp/apicurio_response.json -w "%{http_code}" \
                  -X POST \
                  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
                  --data "$body" \
                  "${APICURIO_URL}/apis/ccompat/v7/subjects/${subject}/versions")
                if [ "$http_code" = "200" ]; then
                  echo "  -> registered, id=$(jq -r '.id // "unknown"' /tmp/apicurio_response.json)"
                elif [ "$http_code" = "409" ]; then
                  echo "  -> already exists (idempotent)"
                else
                  echo "  ERROR: HTTP $http_code for $subject" >&2
                  cat /tmp/apicurio_response.json >&2
                  exit 1
                fi
              }

              for f in /schemas/*.proto; do
                SUBJECT=$(basename "$f" .proto)
                register_proto_schema "$SUBJECT" "$f"
              done

              echo "All schemas registered successfully."
          env:
            - name: APICURIO_URL
              value: {{ $v.schemaRegistration.apicurioUrl | quote }}
          securityContext:
            allowPrivilegeEscalation: false
            runAsNonRoot: false
          resources:
            {{- toYaml $v.schemaRegistration.resources | nindent 12 }}
          volumeMounts:
            - name: schemas
              mountPath: /schemas
      volumes:
        - name: schemas
          configMap:
            name: {{ include "mathtrail-service-lib.fullname" . }}-schema-protos
{{- end }}
{{- end -}}
