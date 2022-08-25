#!/bin/bash
# set -x

# This scripts checks for SMA critical alarms, sending an email if there are.

# Add to crontab, crontab -e
# check every 4 hours.
# 0 */4 * * * /root/sma-sos/sma_alarmcheck.sh [EMAIL_ADDR] >> /tmp/sma_ALARMREPORT.log 2>&1
# check every day at 5am
# 0 5 * * * /root/sma-sos/sma_alarmcheck.sh [EMAIL_ADDR] >> /tmp/sma_ALARMREPORT.log 2>&1

# Check for optional email address to send report.
email=
if [ $# -ge 1 ]; then
	email=$1
fi

server=`hostname`
tag="($server sma_alarmcheck)"

function exists()
{
    command -v "$1" >/dev/null 2>&1
}

echo "Alarm check report generated at `date`"
echo
sma_release=$(cat /etc/opt/cray/release/sma-release)
sma_build=$(echo ${sma_release} | sed -e 's/ RPMS=.*//')
echo ${tag} ${sma_build}

exists "mailx"
if [ $? -ne 0 ]; then
	echo
    echo "Your system does not have mailx installed, mail notification disabled"
    email=
fi

echo
alarms_container=$(docker images --format="{{.ID}}" cray_sma/alarms)
if [ -n "${alarms_container}" ]; then

	alarm_state="$(docker run --name=check_alarms --network=sma_default -v /etc/sma-data:/etc/sma-data -v /root/sma-sos:/root/sma-sos --rm $alarms_container /root/sma-sos/check_alarms.py)"

	echo "----- state"
	num_alarm="$(echo "${alarm_state}" | grep ALARM | wc -l)"
	num_undet="$(echo "${alarm_state}" | grep UNDETERMINED | wc -l)"
	num_ok="$(echo "${alarm_state}" | grep OK | wc -l)"
	total=$((${num_alarm}+${num_undet}+${num_ok}))

	alarm="$(echo "${alarm_state}" | grep ALARM)"
	undet="$(echo "${alarm_state}" | grep UNDETERMINED)"
	ok="$(echo "${alarm_state}" | grep OK)"

	if [ ${num_alarm} -gt 0 ] || [ ${num_undet} -gt 0 ]; then
		if [ -n "${email}" ]; then
			echo "${alarm}" "${undet}" | mail -s "VIEW for ClusterStor on ${server} is reporting critical alarms, $num_alarm ALARM, $num_undet UNDETERMINED" ${email}
		fi
	fi

	echo "${tag} ${num_alarm} ALARM, ${num_undet} UNDETERMINED, ${num_ok} OK alarms were found (${total} total alarms)"
	echo "${alarm}"
	echo "${undet}"
	echo
	echo "${ok}"

	echo
	echo "----- alarm-count"
	docker run --name=alarm-count --network=sma_default -v /etc/sma-data:/etc/sma-data -v /root/sma-sos:/root/sma-sos --rm $alarms_container monasca alarm-count

	echo
	echo "----- alarm-list"
	docker run --name=alarm-list --network=sma_default -v /etc/sma-data:/etc/sma-data -v /root/sma-sos:/root/sma-sos --rm $alarms_container monasca alarm-list

	echo
	echo "----- alarm-history-list"
	docker run --name=alarm-history --network=sma_default -v /etc/sma-data:/etc/sma-data -v /root/sma-sos:/root/sma-sos --rm $alarms_container monasca alarm-history-list

	echo
	echo "----- alarm-definition-list"
	docker run --name=alarm-definition --network=sma_default -v /etc/sma-data:/etc/sma-data -v /root/sma-sos:/root/sma-sos --rm $alarms_container monasca alarm-definition-list

	echo "${tag} Alarm check completed"

else
	echo "${tag} SMA alarms container not loaded...failed"
fi

exit 0

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
