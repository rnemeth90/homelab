{{/*
ConfigMap. Values (root call: .Values.configMap): data, binaryData.
*/}}
{{- define "homelab.configmap" -}}
{{- $root := . }}
{{- $v := dict }}
{{- if hasKey . "root" }}{{ $root = .root }}{{ $v = .values }}{{ else }}{{ $v = .Values.configMap }}{{ end }}
{{- if include "homelab.enabled" $v }}
apiVersion: v1
kind: ConfigMap
metadata:
  {{- include "homelab.metadata" (dict "root" $root "values" $v) | nindent 2 }}
{{- with $v.data }}
data:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $v.binaryData }}
binaryData:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}
