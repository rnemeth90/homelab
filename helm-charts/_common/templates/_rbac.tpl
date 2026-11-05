{{/*
Role / ClusterRole. Values (root call: .Values.role / .Values.clusterRole):
  rules.
*/}}
{{- define "homelab.role" -}}
{{- include "homelab.rbacRole" (list . "Role") }}
{{- end }}

{{- define "homelab.clusterRole" -}}
{{- include "homelab.rbacRole" (list . "ClusterRole") }}
{{- end }}

{{- define "homelab.rbacRole" -}}
{{- $in := index . 0 }}
{{- $kind := index . 1 }}
{{- $root := $in }}
{{- $v := dict }}
{{- if hasKey $in "root" }}{{ $root = $in.root }}{{ $v = $in.values }}{{ else }}{{ $v = index $in.Values (untitle $kind) }}{{ end }}
{{- if include "homelab.enabled" $v }}
apiVersion: rbac.authorization.k8s.io/v1
kind: {{ $kind }}
metadata:
  {{- include "homelab.metadata" (dict "root" $root "values" $v) | nindent 2 }}
rules:
  {{- toYaml $v.rules | nindent 2 }}
{{- end }}
{{- end }}

{{/*
RoleBinding / ClusterRoleBinding. Values (root call: .Values.roleBinding /
.Values.clusterRoleBinding):
  roleRef.kind (default Role / ClusterRole), roleRef.name (default: this
  binding's name), subjects (default: the chart's ServiceAccount, named by
  the chart fullname, in the release namespace).
*/}}
{{- define "homelab.roleBinding" -}}
{{- include "homelab.rbacBinding" (list . "RoleBinding" "Role") }}
{{- end }}

{{- define "homelab.clusterRoleBinding" -}}
{{- include "homelab.rbacBinding" (list . "ClusterRoleBinding" "ClusterRole") }}
{{- end }}

{{- define "homelab.rbacBinding" -}}
{{- $in := index . 0 }}
{{- $kind := index . 1 }}
{{- $roleKind := index . 2 }}
{{- $root := $in }}
{{- $v := dict }}
{{- if hasKey $in "root" }}{{ $root = $in.root }}{{ $v = $in.values }}{{ else }}{{ $v = index $in.Values (untitle $kind) }}{{ end }}
{{- if include "homelab.enabled" $v }}
{{- $ctx := dict "root" $root "values" $v }}
{{- $roleRef := $v.roleRef | default dict }}
apiVersion: rbac.authorization.k8s.io/v1
kind: {{ $kind }}
metadata:
  {{- include "homelab.metadata" $ctx | nindent 2 }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: {{ $roleRef.kind | default $roleKind }}
  name: {{ $roleRef.name | default (include "homelab.resourceName" $ctx) }}
subjects:
  {{- if $v.subjects }}
  {{- toYaml $v.subjects | nindent 2 }}
  {{- else }}
  - kind: ServiceAccount
    name: {{ include "homelab.fullname" $root }}
    namespace: {{ $root.Release.Namespace }}
  {{- end }}
{{- end }}
{{- end }}
