#!/bin/bash

valid_distr="ubuntu"
valid_cmd="init start stop"
valid_component="nova neutron heat murano keystone glance cinder swift sahara"

function remote_init_ubuntu {
	ssh root@node-$1 'bash -s' << EOF
echo "deb http://archive.ubuntu.com/ubuntu/ trusty main restricted universe" >/etc/apt/sources.list
echo "deb-src http://archive.ubuntu.com/ubuntu/ trusty main restricted universe" >>/etc/apt/sources.list
apt-get update
apt-get install -y --force-yes python-pip python-dev gcc
pip install setuptools --upgrade
pip install coverage==4.0a5
rm -rf "/coverage"
mkdir -p "/coverage/rc"
chmod 777 "/coverage"
EOF
}

function remote_neutron_compute_start_ubuntu {
	ssh root@node-$1 'rm -rf "/coverage/neutron";mkdir -p "/coverage/neutron";service neutron-plugin-openvswitch-agent stop > /dev/null 2>&1; echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=neutron" > /coverage/rc/.coveragerc-neutron;cd /coverage/neutron;/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-neutron /usr/bin/neutron-openvswitch-agent --config-file=/etc/neutron/neutron.conf --config-file=/etc/neutron/plugin.ini --log-file=/var/log/neutron/ovs-agent.log > /dev/null 2>&1 &'
}

function remote_neutron_compute_stop_ubuntu {
	ssh root@node-$1 'kill $(ps hf -C coverage | grep "neutron-openvswitch-agent" | awk "{print \$1;exit}");service neutron-plugin-openvswitch-agent start > /dev/null 2>&1'
}

function remote_neutron_controller_start_ubuntu {
	ssh root@node-$1 'for i in p_neutron-plugin-openvswitch-agent p_neutron-dhcp-agent p_neutron-plugin-openvswitch-agent p_neutron-metadata-agent p_neutron-l3-agent; do pcs resource ban ${i} > /dev/null 2>&1; done;service neutron-server stop > /dev/null 2>&1;service neutron-openvswitch-agent stop > /dev/null 2>&1;rm -rf "/coverage/neutron";mkdir -p "/coverage/neutron";echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=neutron" > /coverage/rc/.coveragerc-neutron;cd /coverage/neutron;/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-neutron /usr/bin/neutron-openvswitch-agent --config-file=/etc/neutron/neutron.conf --config-file=/etc/neutron/plugin.ini --log-file=/var/log/neutron/openvswitch-agent.log > /dev/null 2>&1 & /usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-neutron /usr/bin/neutron-server --config-file /etc/neutron/neutron.conf --log-file /var/log/neutron/server.log --config-file /etc/neutron/plugin.ini > /dev/null 2>&1 & for i in dhcp l3 metadata; do /usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-neutron /usr/bin/neutron-${i}-agent --config-file=/etc/neutron/neutron.conf --config-file=/etc/neutron/${i}_agent.ini --log-file=/var/log/neutron/${i}-agent.log > /dev/null 2>&1 & done'
}


function remote_neutron_controller_stop_ubuntu {
	ssh root@node-$1 'for i in neutron-server neutron-openvswitch-agent neutron-dhcp-agent neutron-l3-agent neutron-metadata-agent; do kill $(ps hf -C coverage | grep "${i}" | awk "{print \$1;exit}");done; for i in p_neutron-plugin-openvswitch-agent p_neutron-dhcp-agent p_neutron-plugin-openvswitch-agent p_neutron-metadata-agent p_neutron-l3-agent; do pcs resource clear ${i} > /dev/null 2>&1;done;service neutron-server start > /dev/null 2>&1'
}

function remote_nova_compute_start_ubuntu {
	ssh root@node-$1 'service nova-compute stop > /dev/null 2>&1;rm -rf "/coverage/nova";mkdir -p "/coverage/nova";echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=nova\r\n" >> /coverage/rc/.coveragerc-nova ;cd /coverage/nova;/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-nova /usr/bin/nova-compute --config-file=/etc/nova/nova.conf --config-file=/etc/nova/nova-compute.conf > /dev/null 2>&1 &'
}

function remote_nova_compute_stop_ubuntu {
	ssh root@node-$1 'kill $(ps hf -C coverage | grep "nova-compute" | awk "{print \$1;exit}");service nova-compute start > /dev/null 2>&1'
}

function remote_nova_controller_start_ubuntu {
	ssh root@node-$1 'for i in nova-api nova-novncproxy nova-objectstore nova-consoleauth nova-scheduler nova-conductor nova-cert; do service ${i} stop > /dev/null 2>&1; done; rm -rf "/coverage/nova";mkdir -p "/coverage/nova";echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=nova\r\n" >> /coverage/rc/.coveragerc-nova;cd /coverage/nova;for i in nova-api nova-novncproxy nova-objectstore nova-consoleauth nova-scheduler nova-conductor nova-cert; do /usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-nova /usr/bin/$i --config-file=/etc/nova/nova.conf > /dev/null 2>&1 & done'
}

function remote_nova_controller_stop_ubuntu {
	ssh root@node-$1 'for i in nova-api nova-novncproxy nova-objectstore nova-consoleauth nova-scheduler nova-conductor nova-cert; do kill $(ps hf -C coverage | grep "${i}" | awk "{print \$1;exit}");done;for i in nova-api nova-novncproxy nova-objectstore nova-consoleauth nova-scheduler nova-conductor nova-cert; do service ${i} start; done'
}

function remote_heat_controller_start_ubuntu {
	ssh root@node-$1 'for i in heat-api-cfn heat-api-cloudwatch heat-api; do service ${i} stop; done; pcs resource ban p_heat-engine > /dev/null 2>&1;rm -rf "/coverage/heat"; mkdir -p "/coverage/heat"; echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=heat\r\n" >> /coverage/rc/.coveragerc-heat; cd "/coverage/heat";for i in heat-api-cfn heat-engine heat-api-cloudwatch heat-api; do /usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-heat /usr/bin/${i} >/dev/null 2>&1 & done'
}

function remote_heat_controller_stop_ubuntu {
	ssh root@node-$1 'for i in heat-api-cfn heat-engine heat-api-cloudwatch heat-api; do kill $(ps hf -C coverage | grep "${i}" | awk "{print \$1;exit}");done; for i in heat-api-cfn heat-api-cloudwatch heat-api; do service ${i} start; done; pcs resource clear p_heat-engine > /dev/null 2>&1'
}

function remote_heat_compute_start_ubuntu {
	echo "Skiped node-$1 (compute without heat)"
}

function remote_heat_compute_stop_ubuntu {
	echo "Skiped node-$1 (compute without heat)"
}

##########
function remote_murano_controller_start_ubuntu {
        ssh root@node-$1 'for i in murano-api murano-engine; do service openstack-${i} stop; done;rm -rf "/coverage/murano"; mkdir -p "/coverage/murano"; echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=murano\r\n" >> /coverage/rc/.coveragerc-murano; cd "/coverage/murano";for i in murano-api murano-engine; do /usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-murano /usr/bin/${i} --config-file=/etc/murano/murano.conf >/dev/null 2>&1 & done'
}

function remote_murano_controller_stop_ubuntu {
        ssh root@node-$1 'for i in murano-api murano-engine; do kill $(ps hf -C coverage | grep "${i}" | awk "{print \$1;exit}");done; for i in murano-api murano-engine; do service openstack-${i} start; done'
}

function remote_murano_compute_start_ubuntu {
        echo "Skiped node-$1 (compute without murano)"
}

function remote_murano_compute_stop_ubuntu {
        echo "Skiped node-$1 (compute without murano)"
}

##########

function remote_keystone_controller_start_ubuntu {
        ssh root@node-$1 'service keystone stop;rm -rf "/coverage/keystone"; mkdir -p "/coverage/keystone"; echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=keystone\r\n" >> /coverage/rc/.coveragerc-keystone; cd "/coverage/keystone";/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-keystone /usr/bin/keystone-all >/dev/null 2>&1 &'
}

function remote_keystone_controller_stop_ubuntu {
        ssh root@node-$1 'kill $(ps hf -C coverage | grep "keystone-all" | awk "{print \$1;exit}");service keystone start'
}

function remote_keystone_compute_start_ubuntu {
        echo "Skiped node-$1 (compute without keystone)"
}

function remote_keystone_compute_stop_ubuntu {
        echo "Skiped node-$1 (compute without keystone)"
}


##########

function remote_glance_controller_start_ubuntu {
        ssh root@node-$1 'for i in glance-api glance-registry; do service ${i} stop; done;rm -rf "/coverage/glance"; mkdir -p "/coverage/glance"; echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=glance\r\n" >> /coverage/rc/.coveragerc-glance; cd "/coverage/glance";for i in glance-api glance-registry; do /usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-glance /usr/bin/${i} >/dev/null 2>&1 & done'
}

function remote_glance_controller_stop_ubuntu {
        ssh root@node-$1 'for i in glance-api glance-registry; do kill $(ps hf -C coverage | grep "${i}" | awk "{print \$1;exit}");done; for i in glance-api glance-registry; do service ${i} start; done'
}

function remote_glance_compute_start_ubuntu {
        echo "Skiped node-$1 (compute without glance)"
}

function remote_glance_compute_stop_ubuntu {
        echo "Skiped node-$1 (compute without glance)"
}

##########

function remote_cinder_controller_start_ubuntu {
        ssh root@node-$1 'for i in cinder-api cinder-scheduler; do service ${i} stop; done;rm -rf "/coverage/cinder"; mkdir -p "/coverage/cinder"; echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=cinder\r\n" >> /coverage/rc/.coveragerc-cinder; cd "/coverage/cinder";for i in cinder-api cinder-scheduler; do /usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-cinder /usr/bin/${i} --config-file=/etc/cinder/cinder.conf --log-file=/var/log/cinder/${i}.log >/dev/null 2>&1 & done'
}

function remote_cinder_controller_stop_ubuntu {
        ssh root@node-$1 'for i in cinder-api cinder-scheduler; do kill $(ps hf -C coverage | grep "${i}" | awk "{print \$1;exit}");done; for i in cinder-api cinder-scheduler; do service ${i} start; done'
}

function remote_cinder_compute_start_ubuntu {
        echo "Skiped node-$1 (compute without cinder)"
}

function remote_cinder_compute_stop_ubuntu {
        echo "Skiped node-$1 (compute without cinder)"
}

##########

function remote_swift_controller_start_ubuntu {
        ssh root@node-$1 'for i in swift-account-reaper swift-account swift-account-auditor swift-account-replicator swift-container-replicator swift-container-auditor swift-object-auditor swift-container-sync swift-container swift-proxy swift-object swift-object-replicator swift-container-updater;do service ${i} stop;done;rm -rf "/coverage/swift"; mkdir -p "/coverage/swift"; echo -e "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=swift\r\n" >> /coverage/rc/.coveragerc-swift; cd "/coverage/swift"; for i in account-reaper account-server account-auditor account-replicator container-replicator container-auditor object-auditor container-sync container-server proxy-server object-server object-replicator container-updater; do /usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-swift "/usr/bin/swift-${i}" --config-file="/etc/swift/${i%-*}-server.conf" > /dev/null 2>&1 & done'
}

function remote_swift_controller_stop_ubuntu {
        ssh root@node-$1 'for i in account-reaper account-server account-auditor account-replicator container-replicator container-auditor object-auditor container-sync container-server proxy-server object-server object-replicator container-updater; do kill $(ps hf -C coverage | grep "${i}" | awk "{print \$1;exit}");done; for i in swift-account-reaper swift-account swift-account-auditor swift-account-replicator swift-container-replicator swift-container-auditor swift-object-auditor swift-container-sync swift-container swift-proxy swift-object swift-object-replicator swift-container-updater; do service ${i} start; done'
}

function remote_swift_compute_start_ubuntu {
        echo "Skiped node-$1 (compute without swift)"
}

function remote_swift_compute_stop_ubuntu {
        echo "Skiped node-$1 (compute without swift)"
}

##########

function remote_sahara_controller_start_ubuntu {
        ssh root@node-$1 'service sahara-all stop;rm -rf "/coverage/sahara"; mkdir -p "/coverage/sahara"; echo -e "[run]\r\nomit=\r\n  */openstack/common/*\r\n  .tox/*\r\n  sahara/tests/*\r\n sahara/plugins/vanilla/v1_2_1/*\r\n sahara/plugins/vanilla/v2_3_0/*\r\n sahara/plugins/storm/*\r\ndata_file=.coverage\r\nparallel=True\r\nsource=sahara\r\n" >> /coverage/rc/.coveragerc-sahara; cd "/coverage/sahara";/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-sahara /usr/bin/sahara-all --config-file /etc/sahara/sahara.conf >/dev/null 2>&1 &'
}

function remote_sahara_controller_stop_ubuntu {
        ssh root@node-$1 'kill -2 $(ps hf -C coverage | grep "sahara-all" | awk "{print \$1;exit}");service sahara-all start'
}

function remote_sahara_compute_start_ubuntu {
        echo "Skiped node-$1 (compute without sahara)"
}

function remote_sahara_compute_stop_ubuntu {
        echo "Skiped node-$1 (compute without sahara)"
}


function coverage_stop {
	gen_ctrl=`fuel nodes | grep controller |  awk ' {print $1; exit;} '`
	ssh root@node-$gen_ctrl "mkdir -p /coverage/report/$1"
	mkdir -p /tmp/coverage/report/$1/
	for id in $(fuel nodes | grep compute | awk ' {print $1} ')
	do
		eval "remote_$1_compute_stop_ubuntu $id"
		sleep 25
        	scp root@node-$id:/coverage/$1/.coverage* /tmp/coverage/report/$1/
	done

	for id in $(fuel nodes | grep controller | awk ' {print $1} ')
	do
                eval "remote_$1_controller_stop_ubuntu $id"
		sleep 25
                scp root@node-$id:/coverage/$1/.coverage* /tmp/coverage/report/$1/
	done

	scp /tmp/coverage/report/$1/.coverage* root@node-$gen_ctrl:/coverage/report/$1/
	rm -rf /tmp/coverage
	ssh root@node-$gen_ctrl "cd /coverage/report/$1/; coverage combine; coverage report -m >> report_$1"
	scp root@node-$gen_ctrl:/coverage/report/$1/report_$1 ~/report_$1
	ssh root@node-$gen_ctrl "rm -rf /coverage/report/$1"
	
}

function coverage_start {
	for id in $(fuel nodes | grep compute | awk ' {print $1} ')
	do
		eval "remote_$1_compute_start_ubuntu $id"
	done

	for id in $(fuel nodes | grep controller | awk ' {print $1} ')
	do
		eval "remote_$1_controller_start_ubuntu $id"
	done
}

function coverage_init {
        for id in $(fuel nodes | grep -e '[0-9]' | awk ' {print $1} ')
        do
                remote_init_ubuntu $id
        done
}

function contains() {
   echo -n "Check current host [it's the master node?]....."
   fuel > /dev/null 2>&1 && echo -e '\033[32mYES\033[0m' || eval "echo -e '\033[31mNO\033[0m';exit"
   echo -n "Сheck the specified distribution....."
   [[ $valid_distr =~ (^| )$1($| ) ]] && echo -e '\033[32mOK\033[0m' || echo -e '\033[31mERR\033[0m'
   echo -n "Check the specified command....."
   [[ $valid_cmd =~ (^| )$2($| ) ]] && echo -e '\033[32mOK\033[0m' || echo -e '\033[31mERR\033[0m'
   echo -n "Check the specified component....."
   [[ $valid_component =~ (^| )$3($| ) ]] && echo -e '\033[32mOK\033[0m' || echo -e '\033[31mERR\033[0m'
}

contains $1 $2 $3
case $1 in
     ubuntu)
         case $2 in
		init)
		  coverage_init
		  ;;
		start)
                  coverage_start $3
                  ;;
                stop)
                  coverage_stop $3
                  ;;
		*)
		  exit
		  ;;
         esac
         ;;
     centos)
         case $2 in
                init)
                  ;;
                start)
                  ;;
                stop)
                  ;;
		*)
		  exit
                  ;;
         esac
         ;;
     *)
	exit
        ;; 
esac
