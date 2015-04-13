#!/bin/bash

echo "Kill parent process for Neutron-Service"
kill `ps hf -C coverage | grep "neutron-server" |awk '{ print $1; exit }'`
kill `ps hf -C coverage | grep "neutron-openvswitch-agent" |awk '{ print $1; exit }'`
kill `ps hf -C coverage | grep "neutron-dhcp-agent" |awk '{ print $1; exit }'`
kill `ps hf -C coverage | grep "neutron-l3-agent" |awk '{ print $1; exit }'`
kill `ps hf -C coverage | grep "neutron-metadata-agent" |awk '{ print $1; exit }'`
