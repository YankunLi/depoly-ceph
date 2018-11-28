#!/bin/bash

set -x

usage ()
{
cat <<EOF
Usage :  $0 {options}
Options:
    -r/--resource <resource>   resource is repo,mon,mds,osd etc;
    -c/--command  <command>    what will do about resource
EOF
}

color_print() {
    printf '\033[0;31m%s\033[0m\n' "$1"
}

warn() {
    color_print "WARNNING: $1" >&2
}

die() {
    warn "ERROR: $1"
    exit 1
}

PKG_CEPH_VERSION=""
PKG_CEPH_MON="ceph-mon"
PKG_CEPH_OSD="ceph-osd"
PKG_CEPH_MDS="ceph-mds libcephfs1 python-cephfs ceph-fuse"
PKG_CEPH_ALL="$PKG_CEPH_MDS $PKG_CEPH_MON $PKG_CEPH_OSD"


install_ceph_packages() {
    case $1 in
        mon)
            yum install $PKG_CEPH_MON -y
            ;;
        osd)
            yum install $PKG_CEPH_OSD -y
            ;;
        mds)
            yum install $PKG_CEPH_MDS -y
            ;;
        ceph)
            yum install $PKG_CEPH_ALL -y
            ;;
    esac
}

init_resource() {
    case $1 in
        mon)
            init_mon
            ;;
        osd)
            init_osd
            ;;
        mds)
            init_mds
            ;;
        *)
            ;;
    esac
}

init_mds() {
    if [ -e /var/lib/ceph/mds/ceph-`hostname -s` ]; then
        warn "MDS service is already existed"
        exit 1
    fi
    mkdir /var/lib/ceph/mds/ceph-`hostname -s`
    ceph auth get-or-create mds.`hostname -s` mon 'allow profile mds' mds 'allow *' osd 'allow *' > /var/lib/ceph/mds/ceph-`hostname -s`/keyring
    if [ $? -eq 0 ]; then
        chown ceph:ceph /var/lib/ceph/mds/ceph-`hostname -s` -R
    else
        die "Cann't Create or get keyring for mds `hostname -s`"
    fi
        cat >> /etc/ceph/ceph.conf << EOF
[mds.`hostname -s`]
host=`hostname`
EOF
}

init_mon() {
    //improt global config
    //todo

    if [ CEPH_ALREADY_INIT_FIRST_MON -eq "0" ]; then
        ceph-authtool --create-keyring /tmp/ceph.mon.keyring --gen-key -n mon. --cap mon 'allow *'
        if [ $? -ne 0 ]; then
            die "ERROR: Creating keyring is failed for mon."
        fi
        ceph-authtool --create-keyring /tmp/ceph.client.admin.keyring --gen-key -n client.admin --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow *' --cap mgr 'allow *'
        if [ $? -ne 0 ]; then
            die "ERROR: Creating keyring is failed for client.admin"
        fi
        ceph-authtool --create-keyring /var/lib/ceph/bootstrap-osd/ceph.keyring --gen-key -n client.bootstrap-osd --cap mon 'profile bootstrap-osd'
        if [ $? -ne 0 ]; then
            die "ERROR: Creating keyring is failed for client.bootstrap-osd"
        fi
        ceph-authtool /tmp/ceph.mon.keyring --import-keyring /etc/ceph/ceph.client.admin.keyring
        ceph-authtool /tmp/ceph.mon.keyring --import-keyring /var/lib/ceph/bootstrap-osd/ceph.keyring
        monmaptool --create --add `hostname -s` ip --fsid $CEPH_FSID /tmp/monmap
    else
        ceph auth get mon. -o /tmp/ceph.mon.keyring && ceph mon getmap -o /tmp/monmap
        //todo
    fi
    sudo -u ceph mkdir /var/lib/ceph/mon/ceph-$(hostname -s)
    sudo -u ceph ceph-mon --mkfs -i `hostname -s` --monmap /tmp/monmap --keyring /tmp/ceph.mon.keyring

    //import monitor config
    //start monitor service
}



init_osd() {
    if [ ! -e ./devices-file ]; then
        die "Cann't found devices-file"
    fi
    source ./devices-file  #define variable LOCAL_DEVICES
    for dev in $LOCAL_DEVICES
    do
        if [ -e /$dev/ceph/osd ]; then
            warn "$dev has been initialed for osd"
            continue
        fi
        osd_id=`ceph osd create`
        data=/$dev/ceph/osd/ceph-$osd_id
        mkdir $data -p
        # config osd
    cat >> /etc/ceph/ceph.conf << EOF

[osd.$osd_id]
host=`hostname`
osd_data=/$dev/ceph/osd/ceph-$osd_id
osd_journal_size=10240
osd_journal=/$dev/ceph/osd/ceph-$osd_id/journal
EOF
        ceph-osd -i $osd_id --mkfs --mkjournal --mkkey --osd-uuid `uuidgen` --cluster ceph --osd-data=$data --osd-journal=$data/journal
        if [ $? -ne 0 ]; then
            warn "osd.$osd_id deploy failed"
            continue
        else
            ceph auth add osd.$osd_id osd 'allow *' mon 'allow profile osd' -i $data/keyring
        fi
        chown ceph:ceph -R /$dev/ceph
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

start_osds() {
  #  systemctl start ceph-osd@$osd_id
    osds=$(ceph-conf --cluster=$(cluster:-ceph) -l osd)
    for osd in $osds;
    do
        id=${osd##*.}
        color_print "INFO: Start $osd"
        systemctl start ceph-osd@$id
    done
}

start_resource() {
    case $1 in
        osd)
            start_osds
            ;;
        *)
            ;;
    esac
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
    mon|osd|mds|ceph)
        case $COMMAND in
            install)
                install_ceph_packages $RESOURCE
                ;;
            init)
                init_resource $RESOURCE
                ;;
            start)
                start_resource $RESOURCE
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
