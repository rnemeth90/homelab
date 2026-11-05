{{/*
PersistentVolumeClaim. Values (root call: .Values.persistence):
  enabled, existingClaim (skips rendering), size, storageClass,
  accessModes (list) or accessMode (default ReadWriteOnce).
*/}}
{{- define "homelab.pvc" -}}
{{- $root := . }}
{{- $v := dict }}
{{- if hasKey . "root" }}{{ $root = .root }}{{ $v = .values }}{{ else }}{{ $v = .Values.persistence }}{{ end }}
{{- if and (include "homelab.enabled" $v) (not $v.existingClaim) }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  {{- include "homelab.metadata" (dict "root" $root "values" $v) | nindent 2 }}
spec:
  accessModes:
    {{- toYaml ($v.accessModes | default (list ($v.accessMode | default "ReadWriteOnce"))) | nindent 4 }}
  {{- with $v.storageClass }}
  storageClassName: {{ . | quote }}
  {{- end }}
  resources:
    requests:
      storage: {{ required "persistence size is required" $v.size }}
{{- end }}
{{- end }}
