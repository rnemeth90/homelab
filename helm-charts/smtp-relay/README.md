# SMTP relay

This chart installs an internal Postfix relay. It forwards mail through SMTP2GO
over authenticated TLS; the relay itself is only reachable by pods in the
`prometheus` namespace.

Before Argo CD syncs the chart, create the namespace and an SMTP2GO credential
Secret. Keep the environment file outside the repository and restrict its
permissions:

```sh
kubectl create namespace smtp-relay
umask 077
cat > /secure/path/smtp2go.env <<'EOF'
RELAYHOST_USERNAME=<SMTP2GO username>
RELAYHOST_PASSWORD=<SMTP2GO password>
EOF
kubectl -n smtp-relay create secret generic smtp-relay-credentials \
  --from-env-file=/secure/path/smtp2go.env
rm /secure/path/smtp2go.env
```

In SMTP2GO, verify the sender domain and configure the SPF/DKIM DNS records it
provides. The relay permits senders from `geekyryan.com`; change
`ALLOWED_SENDER_DOMAINS` in `values.yaml` if you use a different verified
domain.

The in-cluster SMTP endpoint is
`smtp-relay.smtp-relay.svc.cluster.local:587`. Point Alertmanager's
`smtp_smarthost` at this endpoint and configure its sender and recipient
addresses separately.
