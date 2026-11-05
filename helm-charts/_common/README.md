# homelab-common

Library chart holding the resource templates shared by the charts in
`helm-charts/`. It renders nothing by itself (and is excluded from the ArgoCD
ApplicationSet); charts pull it in as a local dependency:

```yaml
# <chart>/Chart.yaml
dependencies:
  - name: homelab-common
    version: 0.1.0
    repository: file://../_common
```

Then run `helm dependency update <chart>` once to write `Chart.lock` (the
packaged `charts/*.tgz` is gitignored; ArgoCD rebuilds it on sync).

Templates are prefixed `homelab.` rather than `common.` so they cannot
collide with Bitnami's `common.*` library, which several upstream subcharts
bundle (named templates are global across a chart and its subcharts).

## Templates

| Template | Kind | Root-call values section |
|---|---|---|
| `homelab.deployment` | Deployment | top level of `.Values` |
| `homelab.statefulset` | StatefulSet | `.Values.statefulset` |
| `homelab.pod` | Pod (e.g. helm test hooks) | `.Values.pod` |
| `homelab.service` | Service | `.Values.service` |
| `homelab.ingress` | Ingress | `.Values.ingress` |
| `homelab.gateway` | Gateway (Gateway API) | `.Values.gateway` |
| `homelab.httpRoute` | HTTPRoute | `.Values.gateway` (its `route` block) |
| `homelab.configmap` | ConfigMap | `.Values.configMap` |
| `homelab.secret` | Secret | `.Values.secret` |
| `homelab.pvc` | PersistentVolumeClaim | `.Values.persistence` |
| `homelab.persistentVolume` | PersistentVolume | `.Values.persistentVolume` |
| `homelab.serviceAccount` | ServiceAccount | `.Values.serviceAccount` |
| `homelab.role` / `homelab.clusterRole` | Role / ClusterRole | `.Values.role` / `.Values.clusterRole` |
| `homelab.roleBinding` / `homelab.clusterRoleBinding` | RoleBinding / ClusterRoleBinding | `.Values.roleBinding` / `.Values.clusterRoleBinding` |
| `homelab.hpa` | HorizontalPodAutoscaler | `.Values.autoscaling` |
| `homelab.namespace` | Namespace | dict only |
| `homelab.clusterIssuer` | cert-manager ClusterIssuer | dict only |

The comment at the top of each `templates/_<kind>.tpl` lists the values it
reads. Every template skips rendering when its values have `enabled: false`
or `create: false`.

## Calling conventions

**1. Root context**: the template reads its own section of `.Values`. Most
app charts are just these one-liners:

```yaml
# templates/deployment.yaml
{{ include "homelab.deployment" . }}
```

**2. Explicit values**: pass any map, e.g. a values block with a few
overrides merged in (`merge` keeps the first map's keys):

```yaml
{{ include "homelab.pvc" (dict "root" . "values" (merge (dict "nameSuffix" "-data") .Values.persistence)) }}
```

**3. Named-template YAML**: for anything templated or chart-specific, write
the component's values as YAML in a `define` and hand it to `homelab.render`,
optionally merged over a base map (the YAML wins):

```yaml
{{- define "bind9.service" -}}
selectorLabels:
  app: bind9
ports:
  - {name: dns-udp, port: {{ .Values.service.port }}, protocol: UDP}
{{- end }}
{{ include "homelab.render" (list . "service" "bind9.service" .Values.service) }}
```

## Names and labels

- Resource name: `name`, else the chart fullname plus `nameSuffix`.
- Selector: `selectorLabels` on the component, else `.Values.selectorLabels`,
  else `app.kubernetes.io/name` + `app.kubernetes.io/instance`. Selectors are
  immutable on Deployments/StatefulSets, so charts that predate the library
  (kubedoom, kubernetes-bind, keycloak's Postgres) pin theirs explicitly.
- Metadata labels: the standard `helm.sh/chart`, `app.kubernetes.io/*` set,
  plus the selector and any `labels`.

## Changing the library

Charts lock the library version in `Chart.lock`. Non-breaking template edits
need nothing else (ArgoCD repackages the local dependency on every sync). If
you bump `version` here, update the dependency in every chart and refresh
their locks:

```bash
cd helm-charts
for c in $(grep -l 'file://../_common' */Chart.yaml | xargs -n1 dirname); do
  helm dependency update "$c"
done
```
