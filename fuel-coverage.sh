#!/bin/bash

valid_distr="ubuntu centos"
valid_cmd="init start stop"
valid_component="nova neutron"

function remote_init_ubuntu {
	ssh root@node-$1 'bash -s' << EOF
echo "deb http://archive.ubuntu.com/ubuntu trusty main restricted" >>/etc/apt/sources.list
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
	ssh root@node-$1 'bash -s' << EOF
rm -rf "/coverage/neutron"
mkdir -p "/coverage/neutron"
service neutron-plugin-openvswitch-agent stop > /dev/null 2>&1
echo "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=neutron" > /coverage/rc/.coveragerc-neutron
cd /coverage/neutron
/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-neutron /usr/bin/neutron-openvswitch-agent --config-file=/etc/neutron/neutron.conf --config-file=/etc/neutron/plugin.ini --log-file=/var/log/neutron/ovs-agent.log > /dev/null 2>&1 &
EOF
}

function remote_neutron_compute_stop_ubuntu {
	ssh root@node-$1 'bash -s' << EOF
kill `ps hf -C coverage | grep "neutron-openvswitch-agent" | awk '{ print $1; exit }'`
sleep 5
service neutron-plugin-openvswitch-agent start > /dev/null 2>&1
EOF
}

function remote_neutron_controller_start_ubuntu {
	ssh root@node-$1 'bash -s' << EOF
pcs resource ban p_neutron-plugin-openvswitch-agent > /dev/null 2>&1
pcs resource ban p_neutron-dhcp-agent > /dev/null 2>&1
pcs resource ban p_neutron-plugin-openvswitch-agent > /dev/null 2>&1
pcs resource ban p_neutron-metadata-agent > /dev/null 2>&1
pcs resource ban p_neutron-l3-agent > /dev/null 2>&1
service neutron-server stop > /dev/null 2>&1
service neutron-openvswitch-agent
rm -rf "/coverage/neutron"
mkdir -p "/coverage/neutron"
echo "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=neutron" > /coverage/rc/.coveragerc-neutron
cd /coverage/neutron

/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-neutron /usr/bin/neutron-openvswitch-agent --config-file=/etc/neutron/neutron.conf --config-file=/etc/neutron/plugin.ini --log-file=/var/log/neutron/openvswitch-agent.log > /dev/null 2>&1 &

/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-neutron /usr/bin/neutron-dhcp-agent --config-file=/etc/neutron/neutron.conf --config-file=/etc/neutron/dhcp_agent.ini --log-file=/var/log/neutron/dhcp-agent.log > /dev/null 2>&1 &

/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-neutron /usr/bin/neutron-l3-agent --config-file=/etc/neutron/neutron.conf --config-file=/etc/neutron/l3_agent.ini --log-file=/var/log/neutron/l3-agent.log > /dev/null 2>&1 &

/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-neutron /usr/bin/neutron-metadata-agent --config-file=/etc/neutron/neutron.conf --config-file=/etc/neutron/metadata_agent.ini --log-file=/var/log/neutron/metadata-agent.log > /dev/null 2>&1 &

/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-neutron /usr/bin/neutron-server --config-file /etc/neutron/neutron.conf --log-file /var/log/neutron/server.log --config-file /etc/neutron/plugin.ini > /dev/null 2>&1 &
EOF
}

function remote_neutron_controller_stop_ubuntu {
	ssh root@node-$1 'bash -s' << EOF
kill `ps hf -C coverage | grep "neutron-server" |awk '{ print $1; exit }'`
kill `ps hf -C coverage | grep "neutron-openvswitch-agent" |awk '{ print $1; exit }'`
kill `ps hf -C coverage | grep "neutron-dhcp-agent" |awk '{ print $1; exit }'`
kill `ps hf -C coverage | grep "neutron-l3-agent" |awk '{ print $1; exit }'`
kill `ps hf -C coverage | grep "neutron-metadata-agent" |awk '{ print $1; exit }'`
pcs resource clear p_neutron-plugin-openvswitch-agent > /dev/null 2>&1
pcs resource clear p_neutron-dhcp-agent > /dev/null 2>&1
pcs resource clear p_neutron-plugin-openvswitch-agent > /dev/null 2>&1
pcs resource clear p_neutron-metadata-agent > /dev/null 2>&1
pcs resource clear p_neutron-l3-agent > /dev/null 2>&1
service neutron-server start > /dev/null 2>&1
EOF
}

function remote_nova_compute_start_ubuntu {
	ssh root@node-$1 'bash -s' << EOF
service nova-compute stop > /dev/null 2>&1
rm -rf "/coverage/nova"
mkdir -p "/coverage/nova"
echo "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=nova\r\n" >> /coverage/rc/.coveragerc-nova
cd /coverage/nova
/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-nova /usr/bin/nova-compute --config-file=/etc/nova/nova.conf --config-file=/etc/nova/nova-compute.conf > /dev/null 2>&1 &
EOF
}

function remote_nova_compute_stop_ubuntu {
	ssh root@node-$1  'bash -s' << EOF
kill `ps hf -C coverage | grep "nova-compute" |awk '{ print $1; exit }'`
service nova-compute start > /dev/null 2>&1
EOF
}

function remote_nova_controller_start_ubuntu {
	ssh root@node-$1 'bash -s' << EOF
service nova-api stop > /dev/null 2>&1
service nova-novncproxy stop > /dev/null 2>&1
service nova-objectstore stop > /dev/null 2>&1
service nova-consoleauth stop > /dev/null 2>&1
service nova-scheduler stop > /dev/null 2>&1
service nova-conductor stop > /dev/null 2>&1
service nova-cert stop > /dev/null 2>&1
rm -rf "/coverage/nova"
mkdir -p "/coverage/nova"
echo "[run]\r\ndata_file=.coverage\r\nparallel=True\r\nsource=nova\r\n" >> /coverage/rc/.coveragerc-nova
cd /coverage/nova
/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-nova /usr/bin/nova-api --config-file=/etc/nova/nova.conf > /dev/null 2>&1 &
/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-nova /usr/bin/nova-novncproxy --config-file=/etc/nova/nova.conf > /dev/null 2>&1 &
/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-nova /usr/bin/nova-objectstore --config-file=/etc/nova/nova.conf > /dev/null 2>&1 &
/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-nova /usr/bin/nova-consoleauth --config-file=/etc/nova/nova.conf > /dev/null 2>&1 &
/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-nova /usr/bin/nova-scheduler --config-file=/etc/nova/nova.conf > /dev/null 2>&1 &
/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-nova /usr/bin/nova-conductor --config-file=/etc/nova/nova.conf > /dev/null 2>&1 &
/usr/local/bin/coverage run --rcfile /coverage/rc/.coveragerc-nova /usr/bin/nova-cert --config-file=/etc/nova/nova.conf > /dev/null 2>&1 &
EOF
}

function remote_nova_controller_stop_ubuntu {
	ssh root@node-$1 'bash -s'<< EOF
kill `ps hf -C coverage | grep "nova-api" |awk '{ print $1; exit }'`
kill `ps hf -C coverage | grep "nova-novncproxy" |awk '{ print $1; exit }'`
kill `ps hf -C coverage | grep "nova-objectstore" |awk '{ print $1; exit }'`
kill `ps hf -C coverage | grep "nova-consoleauth" |awk '{ print $1; exit }'`
kill `ps hf -C coverage | grep "nova-scheduler" |awk '{ print $1; exit }'`
kill `ps hf -C coverage | grep "nova-conductor" |awk '{ print $1; exit }'`
kill `ps hf -C coverage | grep "nova-cert" |awk '{ print $1; exit }'`
service nova-api start > /dev/null 2>&1
service nova-novncproxy start > /dev/null 2>&1
service nova-objectstore start > /dev/null 2>&1
service nova-consoleauth start > /dev/null 2>&1
service nova-scheduler start > /dev/null 2>&1
service nova-conductor start > /dev/null 2>&1
service nova-cert start > /dev/null 2>&1a
EOF
}

function coverage_stop {
	gen_comp=`fuel nodes | grep compute |  awk ' {print $1; exit;} '`
	gen_ctrl=`fuel nodes | grep controller |  awk ' {print $1; exit;} '`
	ssh root@node-$gen_comp "mkdir -p /coverage/report/$1"
	ssh root@node-$gen_ctrl "mkdir -p /coverage/report/$1"
	for id in $(fuel nodes | grep compute | awk ' {print $1} ')
	do
		eval "remote_$1_compute_stop_ubuntu $id"
		sleep 5
        	ssh root@node-$id "scp '/coverage/$1/.coverage*' root@node-$gen_comp:/coverage/report/$1/"
	done

	for id in $(fuel nodes | grep controller | awk ' {print $1} ')
	do
                eval "remote_$1_controller_stop_ubuntu $id"
                sleep 5
                ssh root@node-$id "scp '/coverage/$1/.coverage*' root@node-$gen_ctrl:/coverage/report/$1/"
	done

	ssh root@node-$gen_comp "cd /coverage/report/$1; coverage combine; coverage report -m >> report_$1"
	ssh root@node-$gen_ctrl "cd /coverage/general/$1; coverage combine; coverage report -m >> report_$1"
	scp root@node-$gen_comp:/coverage/general/$1/report_$1 ~/report_compute_$1
	scp root@node-$gen_ctrl:/coverage/general/$1/report_$1 ~/report_controller_$1
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
        for id in $(fuel nodes | awk ' {print $1} ')
        do
                remote_init_ubuntu $id
        done
}

function contains() {
  # echo -n "Check current host [it's the master node?]....."
   
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
                  echo "Start"
                  ;;
                stop)
                  echo "Stop"
                  ;;
		*)
		  exit
		  ;;
         esac
         ;;
     centos)
         case $2 in
                init)
                  echo "Init"
                  ;;
                start)
                  echo "Start"
                  ;;
                stop)
                  echo "Stop"
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
