{{/*
HorizontalPodAutoscaler. Values (root call: .Values.autoscaling):
  enabled, minReplicas, maxReplicas, targetCPUUtilizationPercentage,
  targetMemoryUtilizationPercentage, target (Deployment name, default: chart
  fullname).
*/}}
{{- define "homelab.hpa" -}}
{{- $root := . }}
{{- $v := dict }}
{{- if hasKey . "root" }}{{ $root = .root }}{{ $v = .values }}{{ else }}{{ $v = .Values.autoscaling }}{{ end }}
{{- if include "homelab.enabled" $v }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  {{- include "homelab.metadata" (dict "root" $root "values" $v) | nindent 2 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ $v.target | default (include "homelab.fullname" $root) }}
  minReplicas: {{ $v.minReplicas }}
  maxReplicas: {{ $v.maxReplicas }}
  metrics:
    {{- with $v.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ . }}
    {{- end }}
    {{- with $v.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ . }}
    {{- end }}
{{- end }}
{{- end }}
