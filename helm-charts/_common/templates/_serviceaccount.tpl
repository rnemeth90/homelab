{{/*
ServiceAccount. Values (root call: .Values.serviceAccount):
  create, name, annotations, automountServiceAccountToken.
*/}}
{{- define "homelab.serviceAccount" -}}
{{- $root := . }}
{{- $v := dict }}
{{- if hasKey . "root" }}{{ $root = .root }}{{ $v = .values }}{{ else }}{{ $v = .Values.serviceAccount }}{{ end }}
{{- if include "homelab.enabled" $v }}
apiVersion: v1
kind: ServiceAccount
metadata:
  {{- include "homelab.metadata" (dict "root" $root "values" $v) | nindent 2 }}
{{- if hasKey $v "automountServiceAccountToken" }}
automountServiceAccountToken: {{ $v.automountServiceAccountToken }}
{{- end }}
{{- end }}
{{- end }}
