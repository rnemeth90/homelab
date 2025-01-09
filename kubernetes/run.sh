#!/bin/bash

ansible-playbook -i inventory install-dependencies.yml
ansible-playbook -i inventory init-masters.yml
ansible-playbook -i inventory join-workers.yml
ansible-playbook -i inventory apply-network.yml

# Master
firewall-cmd --permanent --add-port=6443/tcp # Kubernetes API server
firewall-cmd --permanent --add-port=2379-2380/tcp # etcd server client API
firewall-cmd --permanent --add-port=10250/tcp # Kubelet API
firewall-cmd --permanent --add-port=10251/tcp # kube-scheduler
firewall-cmd --permanent --add-port=10252/tcp # kube-controller-manager
firewall-cmd --permanent --add-port=8285/udp # Flannel
firewall-cmd --permanent --add-port=8472/udp # Flannel
firewall-cmd --add-masquerade --permanent
# only if you want NodePorts exposed on control plane IP as well
firewall-cmd --permanent --add-port=30000-32767/tcp
firewall-cmd --reload
systemctl restart firewalld
