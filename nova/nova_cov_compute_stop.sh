#!/bin/bash

echo "Kill parent process for Nova-Service"
kill `ps hf -C coverage | grep "nova-compute" |awk '{ print $1; exit }'`
