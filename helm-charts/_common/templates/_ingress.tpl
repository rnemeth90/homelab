{{/*
Ingress. Values (root call: .Values.ingress):
  enabled, ingressClassName (or className), annotations, host,
  path (default /), pathType (default Prefix),
  tls: either {secretName: x} (covers `host`) or a full Ingress tls list,
  serviceName (default: chart fullname),
  servicePort: a number, or a port name (default: .Values.service.port).
*/}}
{{- define "homelab.ingress" -}}
{{- $root := . }}
{{- $v := dict }}
{{- if hasKey . "root" }}{{ $root = .root }}{{ $v = .values }}{{ else }}{{ $v = .Values.ingress }}{{ end }}
{{- if include "homelab.enabled" $v }}
{{- $ctx := dict "root" $root "values" $v }}
{{- $servicePort := $v.servicePort | default ($root.Values.service | default dict).port }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  {{- include "homelab.metadata" $ctx | nindent 2 }}
spec:
  {{- with ($v.ingressClassName | default $v.className) }}
  ingressClassName: {{ . }}
  {{- end }}
  {{- if kindIs "slice" $v.tls }}
  tls:
    {{- toYaml $v.tls | nindent 4 }}
  {{- else if $v.tls }}
  tls:
    - secretName: {{ $v.tls.secretName }}
      hosts:
        - {{ $v.host | quote }}
  {{- end }}
  rules:
    - host: {{ $v.host | quote }}
      http:
        paths:
          - path: {{ $v.path | default "/" }}
            pathType: {{ $v.pathType | default "Prefix" }}
            backend:
              service:
                name: {{ $v.serviceName | default (include "homelab.fullname" $root) }}
                port:
                  {{- if kindIs "string" $servicePort }}
                  name: {{ $servicePort }}
                  {{- else }}
                  number: {{ $servicePort }}
                  {{- end }}
{{- end }}
{{- end }}
