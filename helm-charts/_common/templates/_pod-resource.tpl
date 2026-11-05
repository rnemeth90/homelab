{{/*
Bare Pod (e.g. a helm test hook). Values (root call: .Values.pod):
  everything homelab.podSpec / homelab.container read; put hook annotations
  in `annotations`.
*/}}
{{- define "homelab.pod" -}}
{{- $root := . }}
{{- $v := dict }}
{{- if hasKey . "root" }}{{ $root = .root }}{{ $v = .values }}{{ else }}{{ $v = .Values.pod }}{{ end }}
{{- if include "homelab.enabled" $v }}
{{- $ctx := dict "root" $root "values" $v }}
apiVersion: v1
kind: Pod
metadata:
  {{- include "homelab.metadata" $ctx | nindent 2 }}
spec:
  {{- include "homelab.podSpec" $ctx | nindent 2 }}
{{- end }}
{{- end }}
