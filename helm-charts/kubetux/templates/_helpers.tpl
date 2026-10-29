{{- define "kubetux.name" -}}{{ .Release.Name }}{{- end -}}
{{- define "kubetux.labels" -}}
app.kubernetes.io/name: kubetux
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end -}}
{{- define "kubetux.selector" -}}
app.kubernetes.io/name: kubetux
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "kubetux.verbs" -}}
{{- if .Values.dryRun }}["get","list","watch"]{{ else }}["get","list","watch","delete"]{{ end -}}
{{- end -}}
{{- define "kubetux.secretName" -}}
{{- default (printf "%s-vnc" .Release.Name) .Values.existingSecret -}}
{{- end -}}
