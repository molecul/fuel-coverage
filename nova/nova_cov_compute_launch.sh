#!/bin/bash

echo "Disable Nova Services"
service nova-compute stop > /dev/null 2>&1

echo "Init Coverage"
mkdir -p "/coverage/nova"

echo "Coverage Nova RC File"
cat > /coverage/rc/.coveragerc-nova << EOF
[run]
data_file=.coverage
parallel=True
source=nova
EOF

echo "Run Nova services"
cd /coverage/nova

/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-nova /usr/bin/nova-compute --config-file=/etc/nova/nova.conf --config-file=/etc/nova/nova-compute.conf > /dev/null 2>&1 &
