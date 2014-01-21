#!/bin/bash
#set -x

IFACE1=eth1
IFACE2=eth2

IP_CHECK1=10.0.0.1
IP_CHECK2=10.0.0.1

PING_GAP=0.2
PING_COUNT=5
PING_TIMEOUT=1
# maximum allowed loss percent
LOSS_LIMIT=30
CHECK_GAP=60

LOG_FILE=/var/log/inet-failover.log
STATE_FILE=/var/run/inet-failover

log() {
	#echo "log $@" >  /dev/stderr
	date=$(date '+%Y-%m-%d %H-%M-%S')
	echo "$date $@" | tee $LOG_FILE
}

get_metric() {
	echo "get_metric $@" > /dev/stderr
	local route=$(ip route show dev $1 | grep '^default')
	# default metric is not set or interface not configured
	[ -z "$route" ] && return 1
	echo $route | grep -q 'metric'
	if [ $? -eq 0 ]; then
		local metric=$(echo $route | sed -r 's/.*metric +([0-9]+).*/\1/')
	else
		local metric=0
	fi
	echo ${metric}
}

set_metric() {
	echo "set_metric $@" > /dev/stderr
#	set -x
	local iface=$1
	local metric=$2
	[ -z "$1" -o -z "$2" ] && log "ERROR: incorrect function call: set_metric $@" && return 1
	# route without device and metric
	local route=$(ip route show dev $1 | grep '^default' | head -1 | sed -r 's/metric +[0-9]+//')
	[ -z "$route" ] && log "ERROR: set_metric(): Failed to get default gw metric for $iface" && return 1
	# delete all default routes via interface
	while ip route show dev $iface | grep -q ^default; do
		ip route del default dev $iface
	done
	# add route
	ip route add $route dev $iface metric $metric
#	set +x
}

ping_check() {
	echo "check $@" > /dev/stderr
	local iface=$1
	local ip=$2
	local result=$(ping -i $PING_GAP -c $PING_COUNT -W $PING_TIMEOUT -I $iface $ip | fgrep '%' | egrep -o '[0-9]+%' | tr -d '%')
	# if interface is unavaliable, result may be empty
	echo ${result:-100}
}

# return value is connection "quiality"
get_status() {
	#echo "get_status $@" > /dev/stderr
	local iface=$1
	local r1=$(ping_check $iface $IP_CHECK1)
	local r2=$(ping_check $iface $IP_CHECK2)
	if [ $r1 -lt $LOSS_LIMIT -a $r2 -lt $LOSS_LIMIT ]; then
		echo "OK: loss $r1 and $r2"
	else
		echo "PROBLEM: loss $r1 and $r2"
	fi
	# Quality - arrived packets percent summary
	return $(( 200 - $r1 - $r2 ))
}

log "INFO: Script $0 started"

while true; do
	METRIC1=$(get_metric $IFACE1)
	if [ $? -ne 0 ]; then
		log "ERROR: Failed to get default gateway metric for $IFACE1"
		sleep 1
		continue
	fi
	METRIC2=$(get_metric $IFACE2)
	if [ $? -ne 0 ]; then
		log "ERROR: Failed to get default gw metric for $IFACE2"
		sleep 1
		continue
	fi

	if [ $METRIC1 -lt $METRIC2 ]; then
		MAIN=$IFACE1
		SPARE=$IFACE2
		METRIC_MAIN=$METRIC1
		METRIC_SPARE=$METRIC2
	elif [ $METRIC2 -lt $METRIC1 ]; then
		MAIN=$IFACE2
		SPARE=$IFACE1
		METRIC_MAIN=$METRIC2
		METRIC_SPARE=$METRIC1
	else
		log "ERROR: equal metrics fpr interfaces"
	fi
	echo $MAIN > $STATE_FILE

	MAIN_STATUS=$(get_status $MAIN)
	MAIN_QUALITY=$?
	SPARE_STATUS=$(get_status $SPARE)
	SPARE_QUALITY=$?

	if [[ "$MAIN_STATUS" == OK* && "$SPARE_STATUS" == OK* ]]; then
		echo "OK: channel $MAIN"
		sleep $CHECK_GAP
	elif [[ "$MAIN_STATUS" == OK* && "$SPARE_STATUS" == PROBLEM* ]]; then
		log "PROBLEM: $SPARE channel is bad"
		log "$SPARE_STATUS on $SPARE"
		sleep $CHECK_GAP
	elif [[ "$MAIN_STATUS" == PROBLEM* && "$SPARE_STATUS" == OK* ]]; then
		log "$MAIN_STATUS on $MAIN"
		log "FAILOVER: switching to $SPARE"
		set_metric $MAIN $((METRIC_SPARE+1))
		set_metric $SPARE $METRIC_MAIN
		set_metric $MAIN $METRIC_SPARE
		echo $SPARE > $STATE_FILE
	elif [[ $MAIN_QUALITY -ge $SPARE_QUALITY ]]; then
		log "$MAIN_STATUS in $MAIN"
		log "$SPARE_STATUS in $SPARE"
		log "CRITICAL: all channels bad"
		log "CRITICAL: $SPARE quality is not better than $MAIN"
	else
		log "$MAIN_STATUS in $MAIN"
		log "$SPARE_STATUS in $SPARE"
		log "CRITICAL: all channels bad"
		log "FAILOVER: $SPARE quality seems better than $MAIN"
		log "FAILOVER: switching to $SPARE"
		set_metric $MAIN $((METRIC_SPARE+1))
		set_metric $SPARE $METRIC_MAIN
		set_metric $MAIN $METRIC_SPARE
		echo $SPARE > $STATE_FILE
	fi
done

