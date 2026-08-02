#!usr/bin/bash

LOGFILE="/var/log/sys_health.log"
THRESHOLD=85
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log(){
	echo "$TIMESTAMP - $1" >> "$LOGFILE"
}

LOAD=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1 | xargs)
CORES=$(nproc)
log "CPU Load (1m avg): $LOAD | Cores: $CORES"

MEM_TOTAL=$(free -m | awk -F'Mem:' '{print $2}' | xargs | cut -d' ' -f1)
MEM_USED=$(free -m | awk -F'Mem:' '{print $2}' | xargs | cut -d' ' -f2)
MEM_PER=$(( MEM_USED * 100 / MEM_TOTAL ))
log "Memory Usage: ${MEM_USED}MB / ${MEM_TOTAL}MB (${MEM_PER})"

df -h --output=target,pcent | grep -v "Use%" | while read -r line; do
	MOUNT=$(echo "$line" | awk '{print $1}')
	PERCENT=$(echo "$line" | awk '{print $2}' | tr -d '%')
	log "	$MOUNT -> ${PERCENT}%"
	if [ "$PERCENT" -ge "$THRESHOLD" ]; then
		MSG="ALERT: Disk usage on $MOUNT is at ${PERCENT}% (threshold: ${THRESHOLD}%)"
		log "$MSG"
		logger -t sys_health -p local0.warning "$MSG"
	fi
done
