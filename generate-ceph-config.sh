#!/bin/bash

CURRENT_PATH=$(cd "$(dirname "$0")"; pwd)

CONFIG_PATH=/etc/ceph/

#create_directory() {

if [ -e $CONFIG_PATH ]; then
    if [ -d $CONFIG_PATH ]; then
        echo "Directory $CONFIG_PATH is areadly existed"
    else
        echo "$CONFIG_PATH is existed but is not a directory"
    fi
else
    echo "Donn't found directory $CONFIG_PATH"
    echo "Create new directory $CONFIG_PATH"
    mkdir -p $CONFIG_PATH
fi
#}
#todo check parameter config file
if [ -f $CURRENT_PATH/ceph-parameters-config ]; then
    source $CURRENT_PATH/ceph-parameters-config
else
    echo "ERROR: Cann't found file $CURRENT_PATH/ceph-parameters-config "
    exit 1
fi

if [ -f $CURRENT_PATH/ceph-parameters-config ]; then
    . ./ceph-config-template
else
    echo "ERROR: Cann't found file $CURRENT_PATH/ceph-parameters-config "
    exit 1
fi

generate_conf

