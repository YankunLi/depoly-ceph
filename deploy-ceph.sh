#!/bin/bash

set -x

usage ()
{
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

install_osd()
{
echo "TODO"
}

install_monitor() {
echo "TODO"
}

install_mds() {
echo "TODO"
}

install_ceph() {
echo "TODO"

}

init_osd() {
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
    cat >> /etc/ceph/ceph.conf << EOF
[osd.$osd_id]
host=`hostname`
osd_data=/data0$i/ceph/osd/ceph-$osd_id
osd_journal_size=10240
osd_journal=/data0$i/ceph/osd/ceph-$osd_id/journal
EOF
    done
}

import_repo() {
cat > /etc/yum.repos.d/ceph.repo << EOF
[self-ceph-repo]
name=Extra Packages for Enterprise Linux $releasever - $basearch
baseurl= http://10.148.4.68:8000/centos/7/x86_64/ceph
failovermethod=priority
enabled=1
gpgcheck=0
EOF
}

start_osd() {
  #  systemctl start ceph-osd@$osd_id
/usr/bin/ceph-osd -f --cluster ceph --id $osd_id --setuser work --setgroup work &

}

eval set -- "$(getopt -o r:c: --long resource:,command: -- $@)"

while true
do
    case "$1" in
        -r|--resource)
            RESOURCE=$2
            shift 2;
            ;;
        -c|--command)
            COMMAND=$2
            shift 2;
            ;;
        --)
            shift
            break
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

case $RESOURCE in
    repo)
        case $COMMAND in
            import)
                import_repo
                ;;
            *)
                usage
                exit 1
                ;;
        esac
        ;;
    *)
        usage
        exit 1
        ;;

esac