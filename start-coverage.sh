#!/bin/bash

coverage_sleep="20"
#List enable components
components_enable="nova neutron"

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

function neutron_controller_start {
        ssh root@node-$1 '''
	for i in p_neutron-dhcp-agent p_neutron-metadata-agent p_neutron-l3-agent; 
		do pcs resource disable ${i};
		done;	
	if [[ -f "/etc/centos-release" ]]
		then
			pcs resource disable p_neutron-openvswitch-agent;
                else
              		pcs resource disable p_neutron-plugin-openvswitch-agent;
        	fi;

        for i in server; 
   		do service neutron-$i stop;
                done;
        echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=neutron\r\n" > /coverage/rc/.coveragerc-neutron;
        cd /coverage/neutron;

        if [[ -f "/etc/centos-release" ]]
                        then
                                screen -S neutron-server -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-neutron $(which neutron-server) --config-file /usr/share/neutron/neutron-dist.conf --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugin.ini --log-file /var/log/neutron/server.log;
                        else
                                screen -S neutron-server -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-neutron $(which neutron-server) --config-file /etc/neutron/neutron.conf --log-file /var/log/neutron/server.log --config-file /etc/neutron/plugin.ini;
			fi;
        screen -S neutron-openvswitch-agent -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-neutron $(which neutron-openvswitch-agent) --config-file=/etc/neutron/neutron.conf --config-file=/etc/neutron/plugin.ini --log-file=/var/log/neutron/openvswitch-agent.log;
		

	for i in dhcp l3 metadata; do screen -S neutron-${i}-agent -d -m /usr/bin/python /usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-neutron /usr/bin/neutron-${i}-agent --config-file=/etc/neutron/neutron.conf --config-file=/etc/neutron/${i}_agent.ini --log-file=/var/log/neutron/${i}-agent.log;done
        '''
}

function neutron_controller_stop {
        ssh root@node-$1 '''
                for i in neutron-server openvswitch-agent dhcp-agent l3-agent metadata-agent;
                        do 
                                echo "${i}";
                                kill $(ps hf -C python | grep "${i}" | awk "{print \$1;exit}");
                done;
                for i in dhcp-agent metadata-agent l3-agent;
			do pcs resource enable p_neutron-${i};
		done;
               	if [[ -f "/etc/centos-release" ]]
                                then
                                        pcs resource enable p_neutron-openvswitch-agent;
                                else
                                        pcs resource enable p_neutron-plugin-openvswitch-agent;
                                fi;
		service neutron-server start;
        '''
}

function neutron_compute_start {
        ssh root@node-$1 '''
        for i in openvswitch-agent; 
                do if [[ -f "/etc/centos-release" ]]
                        then
                                service neutron-${i} stop;
                        else
                                service neutron-plugin-${i} stop;
                        fi;
                done;
        echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=neutron\r\n" > /coverage/rc/.coveragerc-neutron;
        cd /coverage/neutron;
        if [[ -f "/etc/centos-release" ]]
                        then
                                screen -S neutron-plugin-openvswitch-agent -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-neutron $(which neutron-openvswitch-agent) --log-file /var/log/neutron/openvswitch-agent.log --config-file /usr/share/neutron/neutron-dist.conf --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini;
                        else
				screen -S neutron-plugin-openvswitch-agent -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-neutron $(which neutron-plugin-openvswitch-agent) --config-file=/etc/neutron/neutron.conf --config-file=/etc/neutron/plugin.ini --log-file=/var/log/neutron/ovs-agent.log;
                        fi;
        '''
}

function neutron_compute_stop {
        ssh root@node-$1 '''
                for i in openvswitch-agent;
                        do if [[ -f "/etc/centos-release" ]]
                                then
					echo "neutron-${i}";
					kill $(ps hf -C python | grep "neutron-${i}" | awk "{print \$1;exit}");
                                        service neutron-${i} start;
                                else
					echo "neutron-plugin-${i}";
                                        kill $(ps hf -C python | grep "neutron-plugin-${i}" | awk "{print \$1;exit}");
                                        service neutron-plugin-${i} start;
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
