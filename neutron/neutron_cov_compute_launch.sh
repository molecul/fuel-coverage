#!/bin/bash

echo "Disable Neutron Services"
service neutron-plugin-openvswitch-agent stop > /dev/null 2>&1

echo "Init Coverage"
mkdir -p "/coverage/neutron"

echo "Coverage Neutron-Server RC File"
cat > /coverage/rc/.coveragerc-neutron << EOF
[run]
data_file=.coverage
parallel=True
source=neutron
EOF

echo "Run Neutron services"
cd /coverage/neutron

/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-neutron /usr/bin/neutron-openvswitch-agent --config-file=/etc/neutron/neutron.conf --config-file=/etc/neutron/plugin.ini --log-file=/var/log/neutron/ovs-agent.log > /dev/null 2>&1 &

