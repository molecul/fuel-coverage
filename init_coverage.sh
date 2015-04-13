#!/bin/bash

echo "deb http://archive.ubuntu.com/ubuntu trusty main restricted" >> /etc/apt/sources.list
apt-get update
apt-get install -y --force-yes python-pip python-dev gcc
pip install coverage==4.0a5
rm -rf "/covegare"
mkdir -p "/coverage/rc"
chmod 777 "/coverage"
