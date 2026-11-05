{{/*
cert-manager ClusterIssuer. Pass a dict; values:
  acme.email, acme.server (default: Let's Encrypt production),
  acme.privateKeySecretName (default: the issuer name), acme.solvers
  or, for non-ACME issuers, a full `spec`.
*/}}
{{- define "homelab.clusterIssuer" -}}
{{- $root := . }}
{{- $v := dict }}
{{- if hasKey . "root" }}{{ $root = .root }}{{ $v = .values }}{{ else }}{{ fail "homelab.clusterIssuer takes (dict \"root\" $ \"values\" ...)" }}{{ end }}
{{- if include "homelab.enabled" $v }}
{{- $ctx := dict "root" $root "values" $v }}
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  {{- include "homelab.metadata" $ctx | nindent 2 }}
spec:
  {{- if $v.acme }}
  acme:
    email: {{ required "acme.email is required" $v.acme.email | quote }}
    server: {{ $v.acme.server | default "https://acme-v02.api.letsencrypt.org/directory" }}
    privateKeySecretRef:
      name: {{ $v.acme.privateKeySecretName | default (include "homelab.resourceName" $ctx) }}
    solvers:
      {{- toYaml $v.acme.solvers | nindent 6 }}
  {{- else }}
  {{- toYaml $v.spec | nindent 2 }}
  {{- end }}
{{- end }}
{{- end }}
