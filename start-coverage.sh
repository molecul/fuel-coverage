#!/bin/bash


coverage_sleep="20"
coverage_dir="/coverage"
#List enable components
components_enable="nova"

function coverage_init {
	rm -rf "/etc/fuel/client/config.yaml"
	for id in $(fuel nodes | grep -e '[0-9]' | awk ' {print $1} ')
        do
		ssh root@node-$id """
		if [[ -f "/etc/centos-release" ]];
		then;
			yum install -y python-pip python-devel gcc;
		else;
			apt-get update;
			apt-get install -y --force-yes python-pip python-dev gcc;
		fi;
		pip install --upgrade setuptools coverage==4.0a5;
		rm -rf $coverage_dir;
		mkdir -p $coverage_dir/rc;
		chmod 777 $coverage_dir;
		"""
	done

function coverage_start {
	for id in $(fuel nodes | grep compute | awk ' {print $1} ')
	do
		ssh root@node-$id "rm -rf $coverage_dir/$1; mkdir -p $coverage_dir/$1"
		eval "${1}_compute_start $id"
	done

	for id in $(fuel nodes | grep controller | awk ' {print $1} ')
	do
	    	ssh root@node-$id "rm -rf $coverage_dir/$1; mkdir -p $coverage_dir/$1"
		eval "${1}_controller_start $id"
	done
}

function coverage_stop {
	gen_ctrl=`fuel nodes | grep controller |  awk ' {print $1; exit;} '`
    	ssh root@node-$gen_ctrl "rm -rf $coverage_dir/report/$1; mkdir -p $coverage_dir/report/$1"
	mkdir -p /tmp/coverage/report/$2/
	for id in $(fuel nodes | grep compute | awk ' {print $1} ')
	do
		eval "${1}_compute_stop $id"
		sleep $coverage_sleep
        	scp root@node-$id:$coverage_dir/$1/.coverage* /tmp/coverage/report/$1/
	done

	for id in $(fuel nodes | grep controller | awk ' {print $1} ')
	do
                eval "${1}_controller_stop $id"
		sleep $coverage_sleep
                scp root@node-$id:$coverage_dir/$1/.coverage* /tmp/coverage/report/$1/
	done

	scp /tmp/coverage/report/$1/.coverage* root@node-$gen_ctrl:$coverage_dir/report/$1/
	rm -rf /tmp/coverage
	ssh root@node-$gen_ctrl "cd $coverage_dir/report/$1/; coverage combine; coverage report --omit=$(python -c 'import os; from $1 import openstack; print os.path.dirname(os.path.abspath(openstack.__file__))')/* -m >> report_$1"
	scp root@node-$gen_ctrl:$coverage_dir/report/$1/report_$1 ~/report_$1_$(date +"%d-%m-%Y_%T")
}

function nova_controller_start {
	ssh root@node-$1 'for i in api novncproxy objectstore consoleauth scheduler conductor cert; do service nova-${i} stop;done;echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=nova\r\n" >> /coverage/rc/.coveragerc-nova;cd /coverage/nova;for i in nova-api nova-novncproxy nova-objectstore nova-consoleauth nova-scheduler nova-conductor nova-cert; do screen -S ${i} -d -m /usr/bin/python /usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-nova /usr/bin/${i} --config-file=/etc/nova/nova.conf;done'
}
