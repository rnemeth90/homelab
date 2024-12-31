#!/bin/bash

ansible-playbook -i inventory install-dependencies.yml
ansible-playbook -i inventory init-masters.yml
ansible-playbook -i inventory join-workers.yml
ansible-playbook -i inventory apply-network.yml
