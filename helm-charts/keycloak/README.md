# Keycloak

Keycloak (codecentric `keycloakx`) + bundled Postgres at https://keycloak.geekyryan.com.
The `homelab` realm (clients `argocd`, `argo-workflows`, group `homelab-admins`, `groups` claim)
is imported from `realm/homelab-realm.json` **only on first start**; later realm changes are made in the UI.

## Secrets (not in git), created before first sync
```
kubectl -n keycloak create secret generic keycloak-admin --from-literal=username=admin --from-literal=password=<pw>
kubectl -n keycloak create secret generic keycloak-db --from-literal=password=<pw>
kubectl -n keycloak create secret generic keycloak-oidc \
  --from-literal=ARGOCD_CLIENT_SECRET=<s1> --from-literal=ARGO_WORKFLOWS_CLIENT_SECRET=<s2>
kubectl -n argocd create secret generic argocd-oidc --from-literal=clientSecret=<s1>
kubectl -n argocd label secret argocd-oidc app.kubernetes.io/part-of=argocd
kubectl -n argo-workflows create secret generic argo-server-sso \
  --from-literal=client-id=argo-workflows --from-literal=client-secret=<s2>
```

## Users
Create users in the `homelab` realm and add them to the `homelab-admins` group
(admin on ArgoCD and Argo Workflows).

## ArgoCD
Not managed by the ApplicationSet; apply OIDC settings with
`helm upgrade argocd argo/argo-cd --version 9.2.3 -n argocd -f helm-charts/argocd/argocd-values.yaml`.
