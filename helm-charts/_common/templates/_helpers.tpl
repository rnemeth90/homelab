{{/*
Naming, labelling and calling-convention helpers shared by every resource
template in this library. See ../README.md for the calling conventions.
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "homelab.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
If release name contains chart name it will be used as a full name.
*/}}
{{- define "homelab.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "homelab.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Default selector labels.
*/}}
{{- define "homelab.selectorLabels" -}}
app.kubernetes.io/name: {{ include "homelab.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "homelab.labels" -}}
helm.sh/chart: {{ include "homelab.chart" . }}
{{ include "homelab.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
The helpers below take a component context: (dict "root" $ "values" $v).
*/}}

{{/*
Non-empty when a component should render: it exists and neither `enabled`
nor `create` is false. Also surfaces fromYaml parse errors, which fromYaml
otherwise reports silently as an "Error" key.
*/}}
{{- define "homelab.enabled" -}}
{{- if kindIs "map" . }}
{{- if hasKey . "Error" }}
{{- fail (printf "homelab-common: invalid component YAML: %v" (get . "Error")) }}
{{- end }}
{{- if and (ne (toString (get . "enabled")) "false") (ne (toString (get . "create")) "false") }}true{{ end }}
{{- end }}
{{- end }}

{{/*
Resource name: `name`, else the chart fullname plus an optional `nameSuffix`.
*/}}
{{- define "homelab.resourceName" -}}
{{- .values.name | default (printf "%s%s" (include "homelab.fullname" .root) (.values.nameSuffix | default "")) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Selector labels: the component's `selectorLabels`, else the chart-wide
.Values.selectorLabels, else the default name/instance pair.
*/}}
{{- define "homelab.selector" -}}
{{- $sel := .values.selectorLabels | default .root.Values.selectorLabels }}
{{- if $sel }}
{{- toYaml $sel }}
{{- else }}
{{- include "homelab.selectorLabels" .root }}
{{- end }}
{{- end }}

{{/*
Metadata labels: common labels, overlaid with the selector and `labels`.
*/}}
{{- define "homelab.resourceLabels" -}}
{{- $labels := include "homelab.labels" .root | fromYaml }}
{{- $labels = mustMergeOverwrite $labels (include "homelab.selector" . | fromYaml) }}
{{- with .values.labels }}
{{- $labels = mustMergeOverwrite $labels . }}
{{- end }}
{{- toYaml $labels }}
{{- end }}

{{/*
Standard metadata block. Pass "annotations" in the context to override the
component's own `annotations` (used when a template adds generated ones).
*/}}
{{- define "homelab.metadata" -}}
name: {{ include "homelab.resourceName" . }}
{{- with .values.namespace }}
namespace: {{ . }}
{{- end }}
labels:
  {{- include "homelab.resourceLabels" . | nindent 2 }}
{{- with (.annotations | default .values.annotations) }}
annotations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Render a component whose values are written as YAML in one of the chart's
own named templates, optionally merged over a base values map (the named
template wins):

  {{ include "homelab.render" (list . "service" "bind9.service" .Values.service) }}

The second argument is the resource template without its "homelab." prefix.
Pass "" as the named template to use the base map alone.
*/}}
{{- define "homelab.render" -}}
{{- $root := index . 0 }}
{{- $v := dict }}
{{- if gt (len .) 2 }}
{{- if index . 2 }}
{{- $v = include (index . 2) $root | fromYaml }}
{{- end }}
{{- end }}
{{- if gt (len .) 3 }}
{{- $v = merge $v (index . 3 | default dict) }}
{{- end }}
{{- include (printf "homelab.%s" (index . 1)) (dict "root" $root "values" $v) }}
{{- end }}
