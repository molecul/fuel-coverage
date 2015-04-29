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
		if [[ -f "/etc/centos-release" ]]
		then
			yum install -y python-pip python-devel gcc;
		else
			apt-get update;
			apt-get install -y --force-yes python-pip python-dev gcc;
		fi;
		pip install --upgrade setuptools coverage==4.0a5;
		rm -rf $coverage_dir;
		mkdir -p $coverage_dir/rc;
		chmod 777 $coverage_dir;
		"""
	done
}

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
	ssh root@node-$gen_ctrl """
		cd $coverage_dir/report/$1/;
		coverage combine;
		coverage report --omit=$(python -c 'import os; from $1 import openstack; print os.path.dirname(os.path.abspath(openstack.__file__))')/* -m >> report_$1
		"""
	scp root@node-$gen_ctrl:$coverage_dir/report/$1/report_$1 ~/report_$1_$(date +"%d-%m-%Y_%T")
	
}

function nova_controller_start {
	ssh root@node-$1 """
	for i in api novncproxy objectstore consoleauth scheduler conductor cert; 
		do if [[ -f '/etc/centos-release' ]]
			then
				service openstack-nova-${i} stop;
			else
				service nova-${i} stop;
			fi;
		done;
	echo -e '[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=nova\r\n\' >> $coverage_dir/rc/.coveragerc-nova;
	cd /coverage/nova;
	if [[ -f '/etc/centos-release' ]]
                        then
                               	screen -S novncproxy -d -m $(which python) $(which coverage) run --rcfile $coverage_dir/rc/.coveragerc-nova $(which openstack-nova-novncproxy) --web /usr/share/novnc/;
                        else
                                screen -S novncproxy -d -m $(which python) $(which coverage) run --rcfile $coverage_dir/rc/.coveragerc-nova $(which nova-novncproxy) --config-file=/etc/nova/nova.conf;
                        fi;
	for i in api objectstore consoleauth scheduler conductor cert;
		do if [[ -f '/etc/centos-release' ]]
			then
				screen -S ${i} -d -m $(which python) $(which coverage) run --rcfile $coverage_dir/rc/.coveragerc-nova $(which openstack-nova-${i}) --logfile /var/log/nova/${i}.log;
			else
				screen -S ${i} -d -m $(which python) $(which coverage) run --rcfile $coverage_dir/rc/.coveragerc-nova $(which nova-${i}) --config-file=/etc/nova/nova.conf;
			fi;
		done;
	"""
}

coverage_init
