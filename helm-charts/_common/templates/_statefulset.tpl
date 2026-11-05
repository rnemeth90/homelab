{{/*
StatefulSet. Values (root call: .Values.statefulset):
  replicaCount, serviceName (default: the resource name), updateStrategy,
  volumeClaimTemplates, selectorLabels,
  plus everything homelab.podTemplate / homelab.podSpec / homelab.container read.
*/}}
{{- define "homelab.statefulset" -}}
{{- $root := . }}
{{- $v := dict }}
{{- if hasKey . "root" }}{{ $root = .root }}{{ $v = .values }}{{ else }}{{ $v = .Values.statefulset }}{{ end }}
{{- if include "homelab.enabled" $v }}
{{- $ctx := dict "root" $root "values" $v }}
apiVersion: apps/v1
kind: StatefulSet
metadata:
  {{- include "homelab.metadata" $ctx | nindent 2 }}
spec:
  serviceName: {{ $v.serviceName | default (include "homelab.resourceName" $ctx) }}
  replicas: {{ if hasKey $v "replicaCount" }}{{ $v.replicaCount }}{{ else }}1{{ end }}
  {{- with $v.updateStrategy }}
  updateStrategy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "homelab.selector" $ctx | nindent 6 }}
  template:
    {{- include "homelab.podTemplate" $ctx | nindent 4 }}
  {{- with $v.volumeClaimTemplates }}
  volumeClaimTemplates:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}
