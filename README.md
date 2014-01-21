# DESCRIPTION
This scripts and config for /etc/network/interfaces allows to use internet from 2 providers simultaneously. Server is avaliable outside from both addresses. Script is used to switch default route if it fails.

I've often seen such setups, each time reinventing the wheel. So I decided to write and share some more common solution for Debian/Ubuntu systems. May be adopted for CentOS/RedHat.

# FEATUES
 * If default provider fails, and it's interface is still alive, default route is switched to other provider.
 * Minimal configuration: you should not write ip addrsses to 100500 places in different scripts, all network parameters are taken from interfaces
 * Conection is checked with ICMP ping to 2 ip addresses, but you can easy add something else to function `get_status()`.
 * Server is avaliable outside from both IP addresses. Necessary tables and rules for policy-based routing are created.
 * Scripts are mistake-proofing: you may use ifup/ifdown mixed with manual interface configuration, routing tables won't be broken.
 * State file with name of currently used default interface.
 * Log file. Both links are monitored, even if only one is used as default.

# NOT SUPPORTED
 * Work with 2 providers on 1 interfaces with aliases: eth0:0 eth0:1
 * Work with default route with load balancing - smth. like "nexthop via $IP1 dev $IFACE1 weight 1 nexthop via $IP2 dev $IFACE2 weight 1"

