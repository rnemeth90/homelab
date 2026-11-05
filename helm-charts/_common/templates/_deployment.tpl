{{/*
Deployment. Values (root call: the top level of .Values):
  replicaCount, strategy, revisionHistoryLimit, selectorLabels,
  plus everything homelab.podTemplate / homelab.podSpec / homelab.container read.
*/}}
{{- define "homelab.deployment" -}}
{{- $root := . }}
{{- $v := dict }}
{{- if hasKey . "root" }}{{ $root = .root }}{{ $v = .values }}{{ else }}{{ $v = .Values }}{{ end }}
{{- if include "homelab.enabled" $v }}
{{- $ctx := dict "root" $root "values" $v }}
apiVersion: apps/v1
kind: Deployment
metadata:
  {{- include "homelab.metadata" $ctx | nindent 2 }}
spec:
  replicas: {{ if hasKey $v "replicaCount" }}{{ $v.replicaCount }}{{ else }}1{{ end }}
  {{- with $v.revisionHistoryLimit }}
  revisionHistoryLimit: {{ . }}
  {{- end }}
  {{- with $v.strategy }}
  strategy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "homelab.selector" $ctx | nindent 6 }}
  template:
    {{- include "homelab.podTemplate" $ctx | nindent 4 }}
{{- end }}
{{- end }}
