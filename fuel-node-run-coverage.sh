#!/bin/bash
for id in $(fuel nodes | grep compute | awk ' {print $1} ')
do
	echo "Compute -> ID: $id"
	ssh root@node-$ip 'bash -s' < init_coverage.sh
	ssh root@node-$ip 'bash -s' < nova/nova_cov_compute_launch.sh
	ssh root@node-$ip 'bash -s' < neutron/neutron_cov_compute_launch.sh
done

for id in $(fuel nodes | grep controller | awk ' {print $1} ')
do
        echo "Controller -> ID: $id"
        ssh root@node-$id 'bash -s' < init_coverage.sh
        ssh root@node-$id 'bash -s' < nova/nova_cov_controller_launch.sh
        ssh root@node-$id 'bash -s' < neutron/neutron_cov_controller_launch.sh
done
