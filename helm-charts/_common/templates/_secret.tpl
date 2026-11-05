{{/*
Secret. Values (root call: .Values.secret):
  type, data (already base64-encoded), stringData.
*/}}
{{- define "homelab.secret" -}}
{{- $root := . }}
{{- $v := dict }}
{{- if hasKey . "root" }}{{ $root = .root }}{{ $v = .values }}{{ else }}{{ $v = .Values.secret }}{{ end }}
{{- if include "homelab.enabled" $v }}
apiVersion: v1
kind: Secret
metadata:
  {{- include "homelab.metadata" (dict "root" $root "values" $v) | nindent 2 }}
{{- with $v.type }}
type: {{ . }}
{{- end }}
{{- with $v.data }}
data:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $v.stringData }}
stringData:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}
