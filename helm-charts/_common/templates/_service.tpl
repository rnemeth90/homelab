{{/*
Service. Values (root call: .Values.service):
  type (default ClusterIP), loadBalancerIP (set via the Cilium LB-IPAM
  annotation), selectorLabels, and either
    port, targetPort (default "http"), portName (default "http"), protocol
  or a full `ports` list.
*/}}
{{- define "homelab.service" -}}
{{- $root := . }}
{{- $v := dict }}
{{- if hasKey . "root" }}{{ $root = .root }}{{ $v = .values }}{{ else }}{{ $v = .Values.service }}{{ end }}
{{- if include "homelab.enabled" $v }}
{{- $ctx := dict "root" $root "values" $v }}
{{- $annotations := merge (dict) ($v.annotations | default dict) }}
{{- with $v.loadBalancerIP }}
{{- $_ := set $annotations "lbipam.cilium.io/ips" (toString .) }}
{{- end }}
apiVersion: v1
kind: Service
metadata:
  {{- include "homelab.metadata" (merge (dict "annotations" $annotations) $ctx) | nindent 2 }}
spec:
  type: {{ $v.type | default "ClusterIP" }}
  ports:
    {{- if $v.ports }}
    {{- toYaml $v.ports | nindent 4 }}
    {{- else }}
    - port: {{ $v.port }}
      targetPort: {{ $v.targetPort | default "http" }}
      protocol: {{ $v.protocol | default "TCP" }}
      name: {{ $v.portName | default "http" }}
    {{- end }}
  selector:
    {{- include "homelab.selector" $ctx | nindent 4 }}
{{- end }}
{{- end }}
