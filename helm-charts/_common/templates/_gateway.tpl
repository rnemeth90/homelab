{{/*
Gateway API Gateway. Values (root call: .Values.gateway):
  enabled, gatewayClassName, clusterIssuer (added as the cert-manager
  annotation), annotations, listeners.
*/}}
{{- define "homelab.gateway" -}}
{{- $root := . }}
{{- $v := dict }}
{{- if hasKey . "root" }}{{ $root = .root }}{{ $v = .values }}{{ else }}{{ $v = .Values.gateway }}{{ end }}
{{- if include "homelab.enabled" $v }}
{{- $annotations := merge (dict) ($v.annotations | default dict) }}
{{- with $v.clusterIssuer }}
{{- $_ := set $annotations "cert-manager.io/cluster-issuer" . }}
{{- end }}
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  {{- include "homelab.metadata" (dict "root" $root "values" $v "annotations" $annotations) | nindent 2 }}
spec:
  gatewayClassName: {{ required "gateway.gatewayClassName is required" $v.gatewayClassName }}
  listeners:
    {{- toYaml $v.listeners | nindent 4 }}
{{- end }}
{{- end }}

{{/*
HTTPRoute attached to the Gateway above. Reads the same values as
homelab.gateway (root call: .Values.gateway), using its `route` block:
  route.hostnames, route.path (default /), route.pathType (default PathPrefix),
  route.serviceName (default: chart fullname),
  route.servicePort (default: .Values.service.port).
*/}}
{{- define "homelab.httpRoute" -}}
{{- $root := . }}
{{- $v := dict }}
{{- if hasKey . "root" }}{{ $root = .root }}{{ $v = .values }}{{ else }}{{ $v = .Values.gateway }}{{ end }}
{{- if include "homelab.enabled" $v }}
{{- $route := $v.route | default dict }}
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  {{- include "homelab.metadata" (dict "root" $root "values" $route) | nindent 2 }}
spec:
  parentRefs:
    - name: {{ include "homelab.resourceName" (dict "root" $root "values" $v) }}
  hostnames:
    {{- toYaml $route.hostnames | nindent 4 }}
  rules:
    - matches:
        - path:
            type: {{ $route.pathType | default "PathPrefix" }}
            value: {{ $route.path | default "/" }}
      backendRefs:
        - name: {{ $route.serviceName | default (include "homelab.fullname" $root) }}
          port: {{ $route.servicePort | default ($root.Values.service | default dict).port }}
{{- end }}
{{- end }}
