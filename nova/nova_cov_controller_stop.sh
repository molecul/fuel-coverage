#!/bin/bash

echo "Kill parent process for Nova-Service"
kill `ps hf -C coverage | grep "nova-api" |awk '{ print $1; exit }'`
kill `ps hf -C coverage | grep "nova-novncproxy" |awk '{ print $1; exit }'`
kill `ps hf -C coverage | grep "nova-objectstore" |awk '{ print $1; exit }'`
kill `ps hf -C coverage | grep "nova-consoleauth" |awk '{ print $1; exit }'`
kill `ps hf -C coverage | grep "nova-scheduler" |awk '{ print $1; exit }'`
kill `ps hf -C coverage | grep "nova-conductor" |awk '{ print $1; exit }'`
kill `ps hf -C coverage | grep "nova-cert" |awk '{ print $1; exit }'`
