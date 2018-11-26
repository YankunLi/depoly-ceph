#!/bin/bash

set -x

function usage() {
cat <<EOF 
Usage $0 : server command {options}
Options:
    -d device to storage ceph osd data
    -s service to operate : osd, mon, mds
EOF
}

color_print() {
    printf '\033[0;31m%s\033[0m\n' "$1"
}

warn() {
    color_print "$1" >&2 
}

die() {
    warn "$1"
    exit 1
}

function install_osd() {}
function install_monitor() {}
function install_mds() {}


function install_ceph() {

}

function init_osd() {
    for i in `seq 4 9`
    do
    #    osd_id=`expr $i + 8`
        osd_id=`ceph osd create`
        data=/data0$i/ceph/osd/ceph-$osd_id
        mkdir $data -p
        ceph-osd -i $osd_id --mkfs --mkjournal --mkkey --osd-uuid `uuidgen` --cluster ceph --osd-data=$data --osd-journal=$data/journal
        if [ $? -ne 0 ]; then
            echo "osd.$osd_id deploy failed"
            continue
        else
            ceph auth add osd.$osd_id osd 'allow *' mon 'allow profile osd' -i $data/keyring
        fi
    #    chown ceph:ceph -R $data
    cat << EOF >> /etc/ceph/ceph.conf
[osd.$osd_id]
host=`hostname`
osd_data=/data0$i/ceph/osd/ceph-$osd_id
osd_journal_size=10240
osd_journal=/data0$i/ceph/osd/ceph-$osd_id/journal
EOF
    done
}

function import_rep() {
cat << EOF > /etc/yum.repos.d/ceph.repo
[self-ceph-repo]
name=Extra Packages for Enterprise Linux $releasever - $basearch
baseurl= http://10.148.4.68:8000/centos/7/x86_64/ceph
failovermethod=priority
enabled=1
gpgcheck=0
EOF
}

function start_osd() {
/usr/bin/ceph-osd -f --cluster ceph --id $osd_id --setuser work --setgroup work &

}

  #  systemctl start ceph-osd@$osd_id
