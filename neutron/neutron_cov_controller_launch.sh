#!/bin/bash

echo "Disable Neutron Services"
pcs resource ban p_neutron-plugin-openvswitch-agent > /dev/null 2>&1
pcs resource ban p_neutron-dhcp-agent > /dev/null 2>&1
pcs resource ban p_neutron-plugin-openvswitch-agent > /dev/null 2>&1
pcs resource ban p_neutron-metadata-agent > /dev/null 2>&1
pcs resource ban p_neutron-l3-agent > /dev/null 2>&1
service neutron-server stop > /dev/null 2>&1
pkill neutron-openvswitch-agent


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

/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-neutron /usr/bin/neutron-openvswitch-agent --config-file=/etc/neutron/neutron.conf --config-file=/etc/neutron/plugin.ini --log-file=/var/log/neutron/openvswitch-agent.log > /dev/null 2>&1 &

/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-neutron /usr/bin/neutron-dhcp-agent --config-file=/etc/neutron/neutron.conf --config-file=/etc/neutron/dhcp_agent.ini --log-file=/var/log/neutron/dhcp-agent.log > /dev/null 2>&1 &

/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-neutron /usr/bin/neutron-l3-agent --config-file=/etc/neutron/neutron.conf --config-file=/etc/neutron/l3_agent.ini --log-file=/var/log/neutron/l3-agent.log > /dev/null 2>&1 &

/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-neutron /usr/bin/neutron-metadata-agent --config-file=/etc/neutron/neutron.conf --config-file=/etc/neutron/metadata_agent.ini --log-file=/var/log/neutron/metadata-agent.log > /dev/null 2>&1 &

/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-neutron /usr/bin/neutron-server --config-file /etc/neutron/neutron.conf --log-file /var/log/neutron/server.log --config-file /etc/neutron/plugin.ini > /dev/null 2>&1 &

