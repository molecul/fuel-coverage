#!/bin/bash

coverage_sleep="20"
#List enable components
components_enable="nova"

function coverage_init {
	rm -rf "/etc/fuel/client/config.yaml"
	echo "LogLevel=quiet" >> ~/.ssh/config
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
		rm -rf /coverage;
		mkdir -p /coverage/rc;
		chmod 777 /coverage;
		"""
	done
}

function coverage_start {
	for id in $(fuel nodes | grep compute | awk ' {print $1} ')
	do
		ssh root@node-$id "rm -rf /coverage/$1; mkdir -p /coverage/$1"
		eval "${1}_compute_start $id"
	done

	for id in $(fuel nodes | grep controller | awk ' {print $1} ')
	do
	    	ssh root@node-$id "rm -rf /coverage/$1; mkdir -p /coverage/$1"
		eval "${1}_controller_start $id"
	done
}

function coverage_stop {
	gen_ctrl=`fuel nodes | grep controller |  awk ' {print $1; exit;} '`
    	ssh root@node-$gen_ctrl "rm -rf /coverage/report/$1; mkdir -p /coverage/report/$1"
	mkdir -p /tmp/coverage/report/$2/
	for id in $(fuel nodes | grep compute | awk ' {print $1} ')
	do
		eval "${1}_compute_stop $id"
		sleep $coverage_sleep
        	scp -r root@node-$id:/coverage/$1 /tmp/coverage/report/
	done

	for id in $(fuel nodes | grep controller | awk ' {print $1} ')
	do
                eval "${1}_controller_stop $id"
		sleep $coverage_sleep
                scp -r root@node-$id:/coverage/$1 /tmp/coverage/report/
	done

	scp -r /tmp/coverage/report/$1 root@node-$gen_ctrl:/coverage/report
	rm -rf /tmp/coverage
	ssh root@node-$gen_ctrl """
		cd /coverage/report/$1/;
		coverage combine;
		coverage report --omit=\`python -c \"import os; from $1 import openstack; print os.path.dirname(os.path.abspath(openstack.__file__))\"\`/* -m >> report_$1
		"""
	scp root@node-$gen_ctrl:/coverage/report/$1/report_$1 ~/report_$1_$(date +"%d-%m-%Y_%T")
	
}

function nova_controller_start {
	ssh root@node-$1 '''
	for i in api novncproxy objectstore consoleauth scheduler conductor cert; 
		do if [[ -f "/etc/centos-release" ]]
			then
				service openstack-nova-$i stop;
			else
				service nova-$i stop;
			fi;
		done;
	echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=nova\r\n" > /coverage/rc/.coveragerc-nova;
	cd /coverage/nova;
	if [[ -f "/etc/centos-release" ]]
                        then
                               	screen -S novncproxy -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-nova $(which nova-novncproxy) --web /usr/share/novnc/;
                        else
                                screen -S novncproxy -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-nova $(which nova-novncproxy) --config-file=/etc/nova/nova.conf;
                        fi;
	for i in api objectstore consoleauth scheduler conductor cert;
		do if [[ -f "/etc/centos-release" ]]
			then
				screen -S ${i} -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-nova $(which nova-${i}) --logfile /var/log/nova/${i}.log;
			else
				screen -S ${i} -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-nova $(which nova-${i}) --config-file=/etc/nova/nova.conf;
			fi;
		done;
	'''
}

function nova_controller_stop {
	ssh root@node-$1 '''
		for i in api novncproxy objectstore consoleauth scheduler conductor cert;
			do 
				echo "nova-${i}";
				kill $(ps hf -C python | grep "nova-${i}" | awk "{print \$1;exit}");
		done;
		for i in api novncproxy objectstore consoleauth scheduler conductor cert;
			do if [[ -f "/etc/centos-release" ]]
                        	then
					service openstack-nova-${i} start;
				else
					service nova-${i} start;
				fi;
		done;
	'''
}

function nova_compute_start {
        ssh root@node-$1 '''
        for i in compute; 
                do if [[ -f "/etc/centos-release" ]]
                        then
                                service openstack-nova-$i stop;
                        else
                                service nova-$i stop;
                        fi;
                done;
        echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=nova\r\n" > /coverage/rc/.coveragerc-nova;
        cd /coverage/nova;
        if [[ -f "/etc/centos-release" ]]
                        then
                                screen -S nova-compute -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-nova $(which nova-compute) --logfile /var/log/nova/compute.log;
                        else
                                screen -S nova-compute -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-nova $(which nova-compute) --config-file=/etc/nova/nova-compute.conf;
                        fi;
        '''
}

function nova_compute_stop {
        ssh root@node-$1 '''
                for i in compute;
                        do 
                                echo "nova-${i}";
                                kill $(ps hf -C python | grep "nova-${i}" | awk "{print \$1;exit}");
                done;
                for i in compute;
                        do if [[ -f "/etc/centos-release" ]]
                                then
                                        service openstack-nova-${i} start;
                                else
                                        service nova-${i} start;
                                fi;
                done;
        '''
}

case $1 in
     init)
	coverage_$1
         ;;
     start)
	coverage_$1 $2
         ;;
     stop)
	coverage_$1 $2
        ;;
     help)
	echo """
		Usage: $0 <command> <component>
			<command>
				init   - Initialize coverage framework 
				start  - Start counting coverage
				stop   - Stop counting coverage and generate report
			<component>
				List of supported components: $components_enable
	     """
	;; 
      *)
	echo -e "Invalid command.\r\nType $0 to get help."
	exit
esac
