#!/bin/bash

echo "Disable Nova Services"
service nova-api stop > /dev/null 2>&1
service nova-novncproxy stop > /dev/null 2>&1
service nova-objectstore stop > /dev/null 2>&1
service nova-consoleauth stop > /dev/null 2>&1
service nova-scheduler stop > /dev/null 2>&1
service nova-conductor stop > /dev/null 2>&1
service nova-cert stop > /dev/null 2>&1

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

/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-nova /usr/bin/nova-api --config-file=/etc/nova/nova.conf > /dev/null 2>&1 &
/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-nova /usr/bin/nova-novncproxy --config-file=/etc/nova/nova.conf > /dev/null 2>&1 &
/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-nova /usr/bin/nova-objectstore --config-file=/etc/nova/nova.conf > /dev/null 2>&1 &
/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-nova /usr/bin/nova-consoleauth --config-file=/etc/nova/nova.conf > /dev/null 2>&1 &
/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-nova /usr/bin/nova-scheduler --config-file=/etc/nova/nova.conf > /dev/null 2>&1 &
/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-nova /usr/bin/nova-conductor --config-file=/etc/nova/nova.conf > /dev/null 2>&1 &
/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-nova /usr/bin/nova-cert --config-file=/etc/nova/nova.conf > /dev/null 2>&1 &
