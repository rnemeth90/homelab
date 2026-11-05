{{/*
Pod-level building blocks shared by Deployment, StatefulSet and Pod.
All take a component context: (dict "root" $ "values" $v).
*/}}

{{/*
Image reference: `image` as a string, or `image.repository:image.tag`
(tag defaults to the chart appVersion).
*/}}
{{- define "homelab.image" -}}
{{- $img := .values.image }}
{{- if kindIs "string" $img }}
{{- $img }}
{{- else }}
{{- $img.repository }}:{{ $img.tag | default .root.Chart.AppVersion }}
{{- end }}
{{- end }}

{{/*
The main container. `containerPort` is shorthand for a single TCP port named
`portName` (default "http"); use `ports` for anything else.
*/}}
{{- define "homelab.container" -}}
{{- $v := .values }}
{{- $pullPolicy := $v.imagePullPolicy }}
{{- if kindIs "map" $v.image }}
{{- $pullPolicy = $v.image.pullPolicy | default $pullPolicy }}
{{- end }}
name: {{ $v.containerName | default .root.Chart.Name }}
image: {{ include "homelab.image" . | quote }}
{{- with $pullPolicy }}
imagePullPolicy: {{ . }}
{{- end }}
{{- with $v.command }}
command:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $v.args }}
args:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $v.env }}
env:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $v.envFrom }}
envFrom:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- if $v.ports }}
ports:
  {{- toYaml $v.ports | nindent 2 }}
{{- else if $v.containerPort }}
ports:
  - name: {{ $v.portName | default "http" }}
    containerPort: {{ $v.containerPort }}
    protocol: TCP
{{- end }}
{{- with $v.startupProbe }}
startupProbe:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $v.readinessProbe }}
readinessProbe:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $v.livenessProbe }}
livenessProbe:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $v.lifecycle }}
lifecycle:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $v.resources }}
resources:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $v.securityContext }}
securityContext:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $v.volumeMounts }}
volumeMounts:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Pod spec: the main container plus pod-level settings.
*/}}
{{- define "homelab.podSpec" -}}
{{- $v := .values }}
{{- with $v.serviceAccountName }}
serviceAccountName: {{ . }}
{{- end }}
{{- if hasKey $v "automountServiceAccountToken" }}
automountServiceAccountToken: {{ $v.automountServiceAccountToken }}
{{- end }}
{{- with $v.podSecurityContext }}
securityContext:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- if hasKey $v "terminationGracePeriodSeconds" }}
terminationGracePeriodSeconds: {{ $v.terminationGracePeriodSeconds }}
{{- end }}
{{- with $v.restartPolicy }}
restartPolicy: {{ . }}
{{- end }}
{{- with $v.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $v.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $v.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $v.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $v.initContainers }}
initContainers:
  {{- toYaml . | nindent 2 }}
{{- end }}
containers:
  - {{ include "homelab.container" . | nindent 4 | trim }}
  {{- with $v.extraContainers }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- with $v.volumes }}
volumes:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Pod template for controllers: selector labels plus `podLabels`, and
`podAnnotations`.
*/}}
{{- define "homelab.podTemplate" -}}
{{- $labels := include "homelab.selector" . | fromYaml }}
{{- with .values.podLabels }}
{{- $labels = mustMergeOverwrite $labels . }}
{{- end }}
metadata:
  labels:
    {{- toYaml $labels | nindent 4 }}
  {{- with .values.podAnnotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- include "homelab.podSpec" . | nindent 2 }}
{{- end }}
