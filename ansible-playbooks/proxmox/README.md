# Proxmox VE

1. `cp inventory.example.ini inventory.ini` and set your host(s).
2. Review `group_vars/proxmox.yaml`.
3. Collections: `ansible-galaxy collection install community.general ansible.posix`
4. Run in order:

```
ansible-playbook 00-configure-repos.yaml
ansible-playbook 01-base-config.yaml
ansible-playbook 02-configure-pve.yaml
```

Proxmox itself must be installed from the ISO first. Set a password for `proxmox_admin_user` manually (`passwd`) after 02 creates it.
