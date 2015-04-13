#!/bin/bash
gen_comp=`fuel nodes | grep compute |  awk ' {print $1; exit;} '`
gen_ctrl=`fuel nodes | grep controller |  awk ' {print $1; exit;} '`

ssh root@node-$gen_comp 'mkdir -p "/coverage/general/nova"; mkdir -p "/coverage/general/nentron";'
ssh root@node-$gen_ctrl 'mkdir -p "/coverage/general/nova"; mkdir -p "/coverage/general/nentron";'

for id in $(fuel nodes | grep compute | awk ' {print $1} ')
do
	echo "Compute -> ID: $id"
	ssh root@node-$id 'bash -s' < nova/nova_cov_compute_stop.sh
	ssh root@node-$id 'bash -s' < neutron/neutron_cov_compute_stop.sh
	sleep 5
        ssh root@node-$id << EOF
scp '/coverage/coverage/rc/.coveragerc-neutron*' root@node-$gen_comp:/coverage/general/nentron/
scp '/coverage/coverage/rc/.coveragerc-nova*' root@node-$gen_comp:/coverage/general/nova/
EOF
done

for id in $(fuel nodes | grep controller | awk ' {print $1} ')
do
        echo "Controller -> ID: $id"
        ssh root@node-$id 'bash -s' < nova/nova_cov_controller_stop.sh
        ssh root@node-$id 'bash -s' < neutron/neutron_cov_controller_stop.sh
        sleep 5
        ssh root@node-$id << EOF
scp '/coverage/coverage/rc/.coveragerc-neutron*' root@node-$gen_ctrl:/coverage/general/nentron/
scp '/coverage/coverage/rc/.coveragerc-nova*' root@node-$gen_ctrl:/coverage/general/nova/
EOF
done

ssh root@node-$gen_comp 'cd /coverage/general/nova; coverage combine; coverage report -m >> report_nova.txt'
ssh root@node-$gen_comp 'cd /coverage/general/neutron; coverage combine; coverage report -m >> report_neutron.txt'
ssh root@node-$gen_ctrl 'cd /coverage/general/nova; coverage combine; coverage report -m >> report_nova.txt'
ssh root@node-$gen_ctrl 'cd /coverage/general/neutron; coverage combine; coverage report -m >> report_neutron.txt'
scp root@node-$gen_comp:/coverage/general/nova/report_nova.txt ~
scp root@node-$gen_comp:/coverage/general/neutron/report_neutron.txt ~
scp root@node-$gen_ctrl:/coverage/general/nova/report_nova.txt ~
scp root@node-$gen_ctrl:/coverage/general/neutron/report_neutron.txt ~
