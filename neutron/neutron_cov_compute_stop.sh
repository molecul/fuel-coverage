#!/bin/bash

echo "Kill parent process for Neutron-Service"
kill `ps hf -C coverage | grep "neutron-openvswitch-agent" |awk '{ print $1; exit }'`
