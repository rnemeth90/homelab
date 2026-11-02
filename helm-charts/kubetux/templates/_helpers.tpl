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
{{- define "kubetux.image" -}}
{{- $tag := .Values.image.tag | default (eq .Values.ui "web" | ternary (printf "%s-web" .Chart.AppVersion) .Chart.AppVersion) -}}
{{ .Values.image.repository }}:{{ $tag }}
{{- end -}}
{{- define "kubetux.resources" -}}
{{- if .Values.resources -}}
{{ toYaml .Values.resources }}
{{- else if eq .Values.ui "web" -}}
requests: {cpu: 50m, memory: 64Mi}
limits: {cpu: 500m, memory: 256Mi}
{{- else -}}
requests: {cpu: 500m, memory: 512Mi}
limits: {cpu: "2", memory: 1Gi}
{{- end -}}
{{- end -}}
{{/* Refuse live mode when nothing protects the game; see values.yaml. */}}
{{- define "kubetux.validate" -}}
{{- if not (has .Values.ui (list "vnc" "web")) -}}
{{- fail (printf "ui must be vnc or web, got %q" .Values.ui) -}}
{{- end -}}
{{- if and (not .Values.dryRun) (not .Values.externalAuth) -}}
{{- if eq .Values.ui "web" -}}
{{- fail "dryRun=false with ui=web lets anyone who can load the page delete pods. Put an auth proxy in front of the game and set externalAuth=true." -}}
{{- else if not (or .Values.vncPassword .Values.existingSecret) -}}
{{- fail "dryRun=false lets anyone who can reach the game delete pods. Set vncPassword or existingSecret (or externalAuth=true if an auth proxy fronts the game)." -}}
{{- end -}}
{{- end -}}
{{- end -}}
