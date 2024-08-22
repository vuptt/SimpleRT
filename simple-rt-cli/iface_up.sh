#!/bin/bash

# SimpleRT: Reverse tethering utility for Android
# Copyright (C) 2016 Konstantin Menyaev
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

PLATFORM=$1
ACTION=$2
TUN_DEV=$3
TUNNEL_NET=$4
HOST_ADDR=$5
TUNNEL_CIDR=$6
NAMESERVER=$7
LOCAL_INTERFACE=$8
shift

set -e

comment="simple_rt"

function linux_start {
    ifconfig $TUN_DEV $HOST_ADDR/$TUNNEL_CIDR up
    sysctl -w net.ipv4.ip_forward=1 > /dev/null
    iptables -I FORWARD -j ACCEPT -m comment --comment "${comment}"
    output_interface_option=""
    if [ -n "$LOCAL_INTERFACE" ]; then
      output_interface_option="-o $LOCAL_INTERFACE"
    fi
    iptables -t nat -I POSTROUTING -s $TUNNEL_NET/$TUNNEL_CIDR $output_interface_option -j MASQUERADE -m comment --comment "${comment}"
}

function linux_stop {
    iptables-save | grep -v "${comment}" | iptables-restore
}

function osx_start {
    ifconfig $TUN_DEV $HOST_ADDR 10.10.10.2 netmask 255.255.255.0 up
    route add -net $TUNNEL_NET $HOST_ADDR
    sysctl -w net.inet.ip.forwarding=1
    echo "nat on $LOCAL_INTERFACE from $TUNNEL_NET/$TUNNEL_CIDR to any -> ($LOCAL_INTERFACE)" > /tmp/nat_rules_rt

    # disable pf
    pfctl -qd 2>&1 > /dev/null || true
    pfctl -qF all 2>&1 > /dev/null || true

    # enable pf with simplert rules
    pfctl -qf /tmp/nat_rules_rt -e
}

function osx_stop {
    # disable pf
    pfctl -qd 2>&1 > /dev/null || true
    pfctl -qF all 2>&1 > /dev/null || true

    # enable pf with system rules
    pfctl -qf /etc/pf.conf -e
}

if [ "$ACTION" = "start" ]; then
    echo configuring:
    echo local interface:       $LOCAL_INTERFACE
    echo virtual interface:     $TUN_DEV
    echo network:               $TUNNEL_NET
    echo address:               $HOST_ADDR
    echo netmask:               $TUNNEL_CIDR
    echo nameserver:            $NAMESERVER
fi

ifconfig $LOCAL_INTERFACE > /dev/null
if [ ! $? -eq 0 ]; then
    echo Supply valid local interface!
    exit 1
fi

cmd="$PLATFORM-$ACTION"

case "$cmd" in
    linux-start)
        linux_start $@
        ;;

    linux-stop)
        linux_stop $@
        ;;

    osx-start)
        osx_start $@
        ;;

    osx-stop)
        osx_stop $@
        ;;

    *)
        echo "Unknown command: $cmd"
        exit 1
esac

exit 0

