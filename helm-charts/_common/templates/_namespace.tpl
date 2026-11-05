{{/*
Namespace. Pass a dict; values: name, labels, annotations.
*/}}
{{- define "homelab.namespace" -}}
{{- $root := . }}
{{- $v := dict }}
{{- if hasKey . "root" }}{{ $root = .root }}{{ $v = .values }}{{ else }}{{ fail "homelab.namespace takes (dict \"root\" $ \"values\" ...)" }}{{ end }}
{{- if include "homelab.enabled" $v }}
apiVersion: v1
kind: Namespace
metadata:
  {{- include "homelab.metadata" (dict "root" $root "values" (omit $v "namespace")) | nindent 2 }}
{{- end }}
{{- end }}
