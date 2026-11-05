{{/*
PersistentVolume. Values (root call: .Values.persistentVolume):
  size, accessModes (default [ReadWriteOnce]), reclaimPolicy (default Retain),
  storageClassName, one volume source (hostPath, nfs or local, passed through),
  and either `node` (pins to that kubernetes.io/hostname) or a full
  `nodeAffinity`.
*/}}
{{- define "homelab.persistentVolume" -}}
{{- $root := . }}
{{- $v := dict }}
{{- if hasKey . "root" }}{{ $root = .root }}{{ $v = .values }}{{ else }}{{ $v = .Values.persistentVolume }}{{ end }}
{{- if include "homelab.enabled" $v }}
apiVersion: v1
kind: PersistentVolume
metadata:
  {{- include "homelab.metadata" (dict "root" $root "values" $v) | nindent 2 }}
spec:
  capacity:
    storage: {{ required "persistentVolume size is required" $v.size }}
  accessModes:
    {{- toYaml ($v.accessModes | default (list "ReadWriteOnce")) | nindent 4 }}
  persistentVolumeReclaimPolicy: {{ $v.reclaimPolicy | default "Retain" }}
  {{- with $v.storageClassName }}
  storageClassName: {{ . }}
  {{- end }}
  {{- range $source := list "hostPath" "nfs" "local" }}
  {{- with get $v $source }}
  {{ $source }}:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- end }}
  {{- if $v.node }}
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - {{ $v.node }}
  {{- else if $v.nodeAffinity }}
  nodeAffinity:
    {{- toYaml $v.nodeAffinity | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}
