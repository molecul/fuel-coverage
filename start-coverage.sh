#!/bin/bash -xe

coverage_sleep="20"
#List enable components
components_enable="nova neutron heat murano keystone glance cinder sahara ceilometer oslo.messaging ironic"

function coverage_init {
	rm -rf "/etc/fuel/client/config.yaml"
	echo "LogLevel=quiet" >> ~/.ssh/config
	for id in $(fuel nodes | grep ready | grep -e '[0-9]' | awk ' {print $1} ')
        do
		ssh root@node-$id """
		if [[ -f "/etc/centos-release" ]];
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
	if [ "${1}" == "cinder" ];
	then	
		for id in $(fuel nodes | grep ready | grep cinder | grep -v "compute" | grep -v "controller" | awk ' {print $1} ')
		do
			ssh root@node-$id "rm -rf /coverage/$1; mkdir -p /coverage/$1"
			eval "cinder_cinder_start $id";
		done
	fi;

	if [ "${1}" == "ironic" ];
	then	
		for id in $(fuel nodes | grep ready | grep ironic | grep -v "compute" | grep -v "controller" | awk ' {print $1} ')
		do
			ssh root@node-$id "rm -rf /coverage/$1; mkdir -p /coverage/$1"
			eval "ironic_ironic_start $id";
		done
	fi;
	
        for id in $(fuel nodes | grep ready | grep compute | awk ' {print $1} ')
       	do
               	ssh root@node-$id "rm -rf /coverage/$1; mkdir -p /coverage/$1"
               	eval "${1}_compute_start $id"
       	done
       	for id in $(fuel nodes | grep ready | grep controller | awk ' {print $1} ')
       	do
               	ssh root@node-$id "rm -rf /coverage/$1; mkdir -p /coverage/$1"
               	rabbit_restart $id
               	eval "${1}_controller_start $id"
       	done
}

function coverage_stop {
	gen_ctrl=`fuel nodes | grep ready | grep controller |  awk ' {print $1; exit;} '`
    	ssh root@node-$gen_ctrl "rm -rf /coverage/report/$1; mkdir -p /coverage/report/$1"
	mkdir -p /tmp/coverage/report/$2/
        if [ "${1}" == "cinder" ];
        then
                for id in $(fuel nodes | grep ready | grep cinder | grep -v "compute" | grep -v "controller" | awk ' {print $1} ')
                do
                        eval "cinder_cinder_stop $id";
                        sleep $coverage_sleep
                        scp -r root@node-$id:/coverage/$1 /tmp/coverage/report/
                done
        fi;

        if [ "${1}" == "ironic" ];
        then
                for id in $(fuel nodes | grep ready | grep ironic | grep -v "compute" | grep -v "controller" | awk ' {print $1} ')
                do
                        eval "ironic_ironic_stop $id";
                        sleep $coverage_sleep
                        scp -r root@node-$id:/coverage/$1 /tmp/coverage/report/
                done
        fi;
        
	for id in $(fuel nodes | grep ready | grep compute | awk ' {print $1} ')
	do
		eval "${1}_compute_stop $id"
		sleep $coverage_sleep
        	scp -r root@node-$id:/coverage/$1 /tmp/coverage/report/
	done
	for id in $(fuel nodes | grep ready | grep controller | awk ' {print $1} ')
	do
               	eval "${1}_controller_stop $id"
		sleep $coverage_sleep
               	scp -r root@node-$id:/coverage/$1 /tmp/coverage/report/
               	rabbit_restart $id
	done
	scp -r /tmp/coverage/report/$1 root@node-$gen_ctrl:/coverage/report
	rm -rf /tmp/coverage
	ssh root@node-$gen_ctrl """
		cd /coverage/report/$1/;
		coverage combine;
		coverage report --omit=\`python -c \"import os; from $1 import openstack; print os.path.dirname(os.path.abspath(openstack.__file__))\"\`/* -m >> report_$1;
		coverage html;
		tar -czvf report_html_$1.tar.gz htmlcov;
		"""
	scp root@node-$gen_ctrl:/coverage/report/$1/report_$1 ~/report_$1
	scp root@node-$gen_ctrl:/coverage/report/$1/report_html_$1.tar.gz ~/report_html_$1.tar.gz
	
	
}

function nova_controller_start {
	ssh root@node-$1 '''
	for i in api novncproxy consoleauth scheduler conductor cert; 
		do if [[ -f "/etc/centos-release" ]];
			then
				service openstack-nova-$i stop;
			else
				service nova-$i stop;
			fi;
		done;
	echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=nova\r\n" > /coverage/rc/.coveragerc-nova;
	cd /coverage/nova;
	if [[ -f "/etc/centos-release" ]];
                        then
                               	screen -S novncproxy -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-nova $(which nova-novncproxy) --web /usr/share/novnc/;
                        else
                                screen -S novncproxy -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-nova $(which nova-novncproxy) --config-file=/etc/nova/nova.conf;
                        fi;
	for i in api consoleauth scheduler conductor cert;
		do if [[ -f "/etc/centos-release" ]];
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
		for i in api novncproxy consoleauth scheduler conductor cert;
			do 
				echo "nova-${i}";
				kill $(ps hf -C python | grep "nova-${i}" | awk "{print \$1;exit}");
		done;
		for i in api novncproxy consoleauth scheduler conductor cert;
			do if [[ -f "/etc/centos-release" ]];
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
                do if [[ -f "/etc/centos-release" ]];
                        then
                                service openstack-nova-$i stop;
                        else
                                service nova-$i stop;
                        fi;
                done;
        echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=nova\r\n" > /coverage/rc/.coveragerc-nova;
        cd /coverage/nova;
        if [[ -f "/etc/centos-release" ]];
                        then
                                screen -S nova-compute -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-nova $(which nova-compute) --logfile /var/log/nova/compute.log;
                        else
                                screen -S nova-compute -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-nova $(which nova-compute) --config-file=/etc/nova/nova.conf --config-file=/etc/nova/nova-compute.conf;
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
                        do if [[ -f "/etc/centos-release" ]];
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
	for i in dhcp metadata l3 openvswitch; 
		do pcs resource disable neutron-${i}-agent;
		done;

        for i in server; 
   		do service neutron-$i stop;
                done;
        echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=neutron\r\n" > /coverage/rc/.coveragerc-neutron;
        cd /coverage/neutron;

        if [[ -f "/etc/centos-release" ]];
                        then
                                screen -S neutron-server -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-neutron $(which neutron-server) --config-file /usr/share/neutron/neutron-dist.conf --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugin.ini --log-file /var/log/neutron/server.log;
                        else
                                screen -S neutron-server -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-neutron $(which neutron-server) --config-file /etc/neutron/neutron.conf --log-file /var/log/neutron/server.log --config-file /etc/neutron/plugins/ml2/ml2_conf.ini;
			fi;
        screen -S neutron-openvswitch-agent -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-neutron $(which neutron-openvswitch-agent) --config-file=/etc/neutron/neutron.conf --config-file=/etc/neutron/plugins/ml2/openvswitch_agent.ini --log-file=/var/log/neutron/openvswitch-agent.log;
		

	for i in dhcp l3 metadata;
		do screen -S neutron-${i}-agent -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-neutron $(which neutron-${i}-agent) --config-file=/etc/neutron/neutron.conf --config-file=/etc/neutron/${i}_agent.ini --log-file=/var/log/neutron/${i}-agent.log;
	done;
        '''
}

function neutron_controller_stop {
        ssh root@node-$1 '''
                for i in neutron-server openvswitch-agent dhcp-agent l3-agent metadata-agent;
                        do 
                                echo "${i}";
                                kill $(ps hf -C python | grep "${i}" | awk "{print \$1;exit}");
                done;
                for i in dhcp metadata l3 openvswitch;
			do pcs resource enable neutron-${i}-agent;
		done;

		service neutron-server start;
        '''
}

function neutron_compute_start {
        ssh root@node-$1 '''
	service neutron-openvswitch-agent stop;
        echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=neutron\r\n" > /coverage/rc/.coveragerc-neutron;
        cd /coverage/neutron;
        if [[ -f "/etc/centos-release" ]];
                        then
                                screen -S neutron-plugin-openvswitch-agent -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-neutron $(which neutron-openvswitch-agent) --log-file /var/log/neutron/openvswitch-agent.log --config-file /usr/share/neutron/neutron-dist.conf --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini;
                        else
				screen -S neutron-openvswitch-agent -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-neutron $(which neutron-openvswitch-agent) --config-file=/etc/neutron/neutron.conf --config-file=/etc/neutron/plugins/ml2/openvswitch_agent.ini --log-file=/var/log/neutron/neutron-openvswitch-agent.log;
                        fi;
        '''
}

function neutron_compute_stop {
        ssh root@node-$1 '''
                for i in openvswitch-agent;
                        do if [[ -f "/etc/centos-release" ]];
                                then
					echo "neutron-${i}";
					kill $(ps hf -C python | grep "neutron-${i}" | awk "{print \$1;exit}");
                                        service neutron-${i} start;
                                else
					echo "neutron-${i}";
                                        kill $(ps hf -C python | grep "neutron-${i}" | awk "{print \$1;exit}");
                                        service neutron-${i} start;
                                fi;
                done;
        '''
}

function heat_controller_start {
	ssh root@node-$1 '''
		for i in heat-api-cfn heat-api-cloudwatch heat-api; 
			do if [[ -f "/etc/centos-release" ]];
				then
					service openstack-${i} stop;
				else
					service ${i} stop;
				fi;
		done;
		if [[ -f "/etc/centos-release" ]];
		then
			pcs resource disable p_openstack-heat-engine;
		else
			pcs resource disable p_heat-engine;
		fi;
		echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=heat\r\n" >> /coverage/rc/.coveragerc-heat; 
		cd "/coverage/heat";
		for i in heat-api-cfn heat-engine heat-api-cloudwatch heat-api;
			do
				if [[ -f "/etc/centos-release" ]];
				then 
					screen -S ${i} -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-heat $(which ${i}) --config-file /etc/heat/heat.conf;
				else
					screen -S ${i} -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-heat $(which ${i});
				fi;
			done;
			'''
}

function heat_controller_stop {
	ssh root@node-$1 '''
		for i in heat-api-cfn heat-engine heat-api-cloudwatch heat-api; 
			do kill $(ps hf -C python | grep "${i}" | awk "{print \$1;exit}");
		done;
		for i in heat-api-cfn heat-api-cloudwatch heat-api;
		do 
			if [[ -f "/etc/centos-release" ]];
			then
				service openstack-${i} start;
			else
				service ${i} start;
			fi;
		done;
		if [[ -f "/etc/centos-release" ]];
		then
			pcs resource enable p_openstack-heat-engine;
		else
			pcs resource enable p_heat-engine;
		fi;
	'''
}

function heat_compute_start {
	true
}

function heat_compute_stop {
	true
}

function keystone_controller_start {
	ssh root@node-$1 '''
		if [[ -f "/etc/centos-release" ]];
		then
			service openstack-keystone stop;
		else
			service keystone stop;
		fi;
		echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=keystone\r\n" >> /coverage/rc/.coveragerc-keystone;
		cd "/coverage/keystone";
		screen -S keystone-all -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-keystone $(which keystone-all) --log-file=/var/log/keystone/keystone.log --config-file=/etc/keystone/keystone.conf;
	'''
}

function keystone_controller_stop {
	ssh root@node-$1 '''
		kill $(ps hf -C python | grep "keystone-all" | awk "{print \$1;exit}");
		if [[ -f "/etc/centos-release" ]];
		then
			service openstack-keystone start;
		else
			service keystone start;
		fi;
	'''
}

function keystone_compute_start {
	true
}

function keystone_compute_stop {
	true
}

function murano_controller_start {
	ssh root@node-$1 '''
		for i in murano-api murano-engine;
			do 
				service ${i} stop;
			done;
		
		echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=murano\r\n" >> /coverage/rc/.coveragerc-murano;
		cd "/coverage/murano";
		
		for i in murano-api murano-engine;
			do
				screen -S ${i} -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-murano $(which ${i}) --log-file=/var/log/murano/${i}.log --config-file=/etc/murano/murano.conf;
			done;
	'''
}

function murano_controller_stop {
	ssh root@node-$1 '''
		for i in murano-api murano-engine;
			do
				kill $(ps hf -C python | grep "${i}" | awk "{print \$1;exit}");
			done;
		for i in murano-api murano-engine;
			do 
				service ${i} start;
			done;
	'''
}

function murano_compute_start {
	true
}

function murano_compute_stop {
	true
}

function glance_controller_start {
	ssh root@node-$1 '''
		for i in glance-api glance-registry glance-glare;
			do
				if [[ -f "/etc/centos-release" ]];
				then
					service openstack-${i} stop;
				else
					service ${i} stop;
				fi;
			done;
		echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=glance\r\n" >> /coverage/rc/.coveragerc-glance;
		cd "/coverage/glance";
		for i in glance-api glance-registry;
			do 
				screen -S ${i} -d -m  $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-glance $(which ${i});
		done;
	'''
}

function glance_controller_stop {
	ssh root@node-$1 '''
		for i in glance-api glance-registry glance-glare;
			do
				kill $(ps hf -C python | grep "${i}" | awk "{print \$1;exit}");
			done;
		for i in glance-api glance-registry glance-glare;
			do 
                                if [[ -f "/etc/centos-release" ]];
                                then
                                        service openstack-${i} start;
                                else
                                        service ${i} start;
                                fi;
			done;
	'''
}

function glance_compute_start {
	true
}

function glance_compute_stop {
	true
}

function cinder_controller_start {
	ssh root@node-$1 '''
		for i in cinder-api cinder-scheduler cinder-backup cinder-volume;
                        do
                                if [[ -f "/etc/centos-release" ]];
                                then
                                        service openstack-${i} stop;
                                else
                                        service ${i} stop;
                                fi;
                        done;

		echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=cinder\r\n" >> /coverage/rc/.coveragerc-cinder;
		cd "/coverage/cinder";
		for i in api scheduler backup volume;
			do
				if [[ -f "/etc/centos-release" ]];
				then
					screen -S ${i} -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-cinder $(which cinder-${i}) --config-file /usr/share/cinder/cinder-dist.conf --config-file /etc/cinder/cinder.conf --logfile /var/log/cinder/${i}.log;
				else
					screen -S ${i} -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-cinder $(which cinder-${i}) --config-file=/etc/cinder/cinder.conf --log-file=/var/log/cinder/cinder-${i}.log;
				fi;
			done;
	'''
}

function cinder_controller_stop {
	ssh root@node-$1 '''
		for i in cinder-api cinder-scheduler cinder-backup cinder-volume;
			do
				kill $(ps hf -C python | grep "${i}" | awk "{print \$1;exit}");
			done;
		for i in cinder-api cinder-scheduler cinder-backup cinder-volume; 
                        do
                                if [[ -f "/etc/centos-release" ]];
                                then
                                        service openstack-${i} start;
                                else
                                        service ${i} start;
                                fi;
                        done;

	'''
}

function cinder_compute_start {
	true
}

function cinder_compute_stop {
	true
}

function cinder_cinder_start {
	ssh root@node-$1 '''
		echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=cinder\r\n" >> /coverage/rc/.coveragerc-cinder;
                cd "/coverage/cinder";
		if [[ -f "/etc/centos-release" ]];
		then
			service openstack-cinder-volume stop;
			screen -S cinder-volume -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-cinder $(which cinder-volume) --config-file=/etc/cinder/cinder.conf --log-file=/var/log/cinder/cinder-volume.log;
		else
			service cinder-volume stop;
			screen -S cinder-volume -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-cinder $(which cinder-volume) --config-file=/etc/cinder/cinder.conf --log-file=/var/log/cinder/cinder-volume.log;
		fi;
	'''
}

function cinder_cinder_stop {
	ssh root@node-$1 '''
		kill $(ps hf -C python | grep "cinder-volume" | awk "{print \$1;exit}");
		if [[ -f "/etc/centos-release" ]];
		then
			service openstack-cinder-volume start;
		else
			service cinder-volume start;
		fi;
	'''
}

function sahara_controller_start {
	ssh root@node-$1 '''
		echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=sahara\r\n" >> /coverage/rc/.coveragerc-sahara;
		cd "/coverage/sahara";
		for i in sahara-api sahara-engine;
		do
		  service ${i} stop;
		  screen -S ${i} -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-sahara $(which ${i}) --config-file /etc/sahara/sahara.conf;
		done;
		'''
}

function sahara_controller_stop {
	ssh root@node-$1 '''
	        for i in sahara-api sahara-engine;
	        do 
		kill -2 $(ps hf -C python | grep ${i} | awk "{print \$1;exit}");
		service ${i} stop;
		done;
	'''
}

function sahara_compute_start {
	true
}

function sahara_compute_stop {
	true
}

function ceilometer_controller_start {
	ssh root@node-$1 '''
		for i in ceilometer-agent-notification ceilometer-api ceilometer-collector ceilometer-polling; 
		do 
			service $i stop;
		done;
		for i in p_ceilometer-agent-central;
		do 
			pcs resource disable ${i};
		done; 
		echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=ceilometer\r\n" >> /coverage/rc/.coveragerc-ceilometer;
		cd /coverage/ceilometer; 
		for i in ceilometer-agent-central ceilometer-agent-notification ceilometer-api ceilometer-collector; 
		do
		    screen -S ${i} -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-ceilometer $(which ${i}) --log-file=/var/log/ceilometer/${i}.log --config-file=/etc/ceilometer/ceilometer.conf;
		done;
		screen -S ceilometer-polling -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-ceilometer $(which ceilometer-polling) --polling-namespaces central --config-file=/etc/ceilometer/ceilometer.conf;
	'''
}

function ceilometer_controller_stop {
	ssh root@node-$1 '''
		for i in ceilometer-agent-notification ceilometer-api ceilometer-collector ceilometer-polling ceilometer-agent-central;
		do 
			kill $(ps hf -C python | grep "${i}" | awk "{print \$1;exit}");
		done;
		for i in ceilometer-agent-notification ceilometer-api ceilometer-collector ceilometer-polling;
		do
			service ${i} start;
		done;
		for i in p_ceilometer-agent-central;
		do 
			pcs resource enable ${i};
		done;
	'''
}

function ceilometer_compute_start {
	ssh root@node-$1 '''
		service ceilometer-polling;
		echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=ceilometer\r\n" >> /coverage/rc/.coveragerc-ceilometer;
		cd /coverage/ceilometer;
		screen -S ceilometer-polling -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-ceilometer $(which ceilometer-polling) --config-file=/etc/ceilometer/ceilometer.conf --log-file=/var/log/ceilometer/ceilometer-polling.log;
	'''
}

function ceilometer_compute_stop {
	ssh root@node-$1 '''
		kill $(ps hf -C python | grep ceilometer-polling | awk "{print \$1;exit}");
		service ceilometer-polling start;
	'''
}

function oslo.messaging_controller_start {
	ssh root@node-$1 '''
        OSLO_MESSAGING_INIT=`python -c "import oslo.messaging; print oslo.messaging.__file__" | sed s/.pyc$/.py/`
        OSLO_MESSAGING_PATH=`python -c "import oslo.messaging; print oslo.messaging.__path__[0]"`
        cp ${OSLO_MESSAGING_INIT} ${OSLO_MESSAGING_INIT}.bkp
        sed -i "1 i\import coverage\n\ncov = coverage.coverage(\n    auto_data=True,\n    data_file=\".coverage\",\n    config_file=False,\n    source=[\"${OSLO_MESSAGING_PATH}\"],\n    omit=[\"${OSLO_MESSAGING_PATH}/tests/*\"])\n\ncov.start()\n\n" ${OSLO_MESSAGING_INIT}
        sudo reboot
	'''
}

function oslo.messaging_controller_stop {
	ssh root@node-$1 '''
        OSLO_MESSAGING_INIT=`python -c "import oslo.messaging; print oslo.messaging.__file__" | sed s/.pyc$/.py/`
        mv ${OSLO_MESSAGING_INIT}.bkp ${OSLO_MESSAGING_INIT}
        rm ${OSLO_MESSAGING_INIT}c # remove .pyc file
        sudo reboot
	'''
    # Check, that node is up and receive ssh connection
    ssh root@node-$1 exit
    while [ $? -gt 0 ]; do
        sleep 3
        ssh root@node-$1 exit
    done
}

function oslo.messaging_compute_start {
	ssh root@node-$1 '''
        OSLO_MESSAGING_INIT=`python -c "import oslo.messaging; print oslo.messaging.__file__" | sed s/.pyc$/.py/`
        OSLO_MESSAGING_PATH=`python -c "import oslo.messaging; print oslo.messaging.__path__[0]"`
        cp ${OSLO_MESSAGING_INIT} ${OSLO_MESSAGING_INIT}.bkp
        sed -i "1 i\import coverage\n\ncov = coverage.coverage(\n    auto_data=True,\n    data_file=\".coverage\",\n    config_file=False,\n    source=[\"${OSLO_MESSAGING_PATH}\"],\n    omit=[\"${OSLO_MESSAGING_PATH}/tests/*\"])\n\ncov.start()\n\n" ${OSLO_MESSAGING_INIT}
        sudo reboot
	'''
}

function oslo.messaging_compute_stop {
	ssh root@node-$1 '''
        OSLO_MESSAGING_INIT=`python -c "import oslo.messaging; print oslo.messaging.__file__" | sed s/.pyc$/.py/`
        mv ${OSLO_MESSAGING_INIT}.bkp ${OSLO_MESSAGING_INIT}
        rm ${OSLO_MESSAGING_INIT}c # remove .pyc file
        sudo reboot
	'''
    # Check, that node is up and receive ssh connection
    ssh root@node-$1 exit
    while [ $? -gt 0 ]; do
        sleep 3
        ssh root@node-$1 exit
    done
}


function swift_controller_start {
	ssh root@node-$1 '''
	echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=swift\r\n" >> /coverage/rc/.coveragerc-swift;
	for i in object account-auditor object-updater container-replicator account-replicator object-replicator container-auditor container-sync proxy account-reaper container object-auditor account container-updater;
	 do
	  initctl stop swift-${i};
	 done;
	for i in server updater replicator auditor;
	 do
	  screen -S swift-object-${i} -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-swift $(which swift-object-${i}) /etc/swift/object-server.conf;
	 done;
	 
	for i in server reaper replicator auditor;
	 do
	  screen -S swift-account-${i} -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-swift $(which swift-account-${i}) /etc/swift/account-server.conf;
	 done;
	 
	for i in replicator auditor sync server updater;
	 do
	  screen -S swift-container-${i} -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-swift $(which swift-container-${i}) /etc/swift/container-server.conf;
	 done;
	
	screen -S swift-proxy-server -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-swift $(which swift-proxy-server) /etc/swift/proxy-server.conf;
	'''
}

function swift_controller_stop {
	ssh root@node-$1 '''
	        for i in object account-auditor object-updater container-replicator account-replicator object-replicator container-auditor container-sync proxy account-reaper container object-auditor account container-updater; do
		kill -2 $(ps hf -C python | grep swift-${i} | awk "{print \$1;exit}");
		service swift-${i} start;
		done;
	'''
}

function swift_compute_start {
	true
}

function swift_compute_stop {
	true
}

function ironic_controller_start {
	ssh root@node-$1 '''
		service ironic-api stop;
		echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=ironic\r\n" >> /coverage/rc/.coveragerc-ironic;
		cd "/coverage/ironic";
		screen -S ironic-api -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-ironic $(which ironic-api) --log-file=/var/log/ironic/ironic-api.log --config-file=/etc/ironic/ironic.conf;
			'''
}

function ironic_controller_stop {
	ssh root@node-$1 '''
		kill -2 $(ps hf -C python | grep "ironic-api" | awk "{print \$1;exit}");
		service ironic-api start;
	'''
}

function ironic_compute_start {
	true
}

function ironic_compute_stop {
	true
}

function ironic_ironic_start {
	ssh root@node-$1 '''
		service ironic-conductor stop;
		echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=ironic\r\n" >> /coverage/rc/.coveragerc-ironic;
		cd "/coverage/ironic";
		screen -S ironic-conductor -d -m $(which python) $(which coverage) run --rcfile /coverage/rc/.coveragerc-ironic $(which ironic-conductor) --log-file=/var/log/ironic/ironic-conductor.log --config-file=/etc/ironic/ironic.conf;
			'''
}

function ironic_ironic_stop {
	ssh root@node-$1 '''
		kill -2 $(ps hf -C python | grep "ironic-conductor" | awk "{print \$1;exit}");
		service ironic-conductor start;
	'''
}


function rabbit_restart {
	ssh root@node-$1 '''
		if [[ -f "/etc/centos-release" ]];
		
		then
			echo "Restart RabbitMQ"
			pcs resource disable master_p_rabbitmq-server;
			pcs resource enable master_p_rabbitmq-server;
		else
			echo "Restart RabbitMQ"
			pcs resource disable master_p_rabbitmq-server;
			pcs resource enable master_p_rabbitmq-server;
		fi;
	'''
}

case $1 in
     init)
	coverage_$1
         ;;
     start)
	[[ $components_enable =~ (^| )$2($| ) ]] && coverage_$1 $2 || echo -e '\033[31mUnknown component\033[0m'
	 ;;
     stop)
	[[ $components_enable =~ (^| )$2($| ) ]] && coverage_$1 $2 || echo -e '\033[31mUnknown component\033[0m'
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
