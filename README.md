# DESCRIPTION
This scripts and config for /etc/network/interfaces allows to use internet from 2 providers simultaneously. Server is avaliable outside from both addresses. Script is used to switch default route if it fails.

I've often seen such setups, each time reinventing the wheel. So I decided to write some more common solution.

# FEATUES
 * If default provider fails, and it's interface is still alive, default route is switched to other provider
 * Server is avaliable outside from both IP addresses. Necessary tables and rules for policy-based routing are created.
 * Scripts are mistake-proofing: you may use ifup/ifdown mixed with manual interface configuration, routing tables won't be broken
 * State file with name of currently used default interface is updated
 * Log file

