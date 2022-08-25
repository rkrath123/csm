#!/bin/bash
# set -x

BINPATH=`dirname "$0"`
. $BINPATH/sma_tools

function usage()
{
    echo "usage: $0"
    echo
    echo "This command checks if the telemetry api appears healthy."
    echo "$0 > sma_KAFKA_HEALTH-\`date +%Y%m%d.%H%M\`"
    echo
    exit 1
}

while getopts h option
do
    case "${option}"
    in
        h) usage;;
    esac
done
shift $((OPTIND-1))
[ "$1" = "--" ] && shift

iters=10

kubectl version > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echoerr "unable to talk to kubectl"
	exit 3
fi

show_shasta_config
echo

ping -c 3 ${SMA_API_GATEWAY} >/dev/null 2>&1
if [ "$?" -ne 0 ]; then
	echoerr "${SMA_API_GATEWAY} service is not healthy"
	exit 1
fi

url="http://${SMA_API_GATEWAY}/apis/sma-telemetry-api/v1"

# get access token for authentication
auth_token=$(sma_get_auth_token)
echo "Auth token"
echo ${auth_token}
if grep -q "Error" <<< "${auth_token}"; then
	exit 1
fi
invalid_auth_token="invalid auth token"

echo
kubectl -n services get pods -owide | grep telemetry-api

errs=0

######################
# ping API, no auth
######################
echo
fail=0
health_check="Telemetry api ping (no auth)"
echo "curl -s ${url}/ping"

for i in $(seq 1 $iters);
do
	res=$(curl -s ${url}/ping)
	if [ "$?" -ne 0 ]; then
		fail=$((fail+1))
	fi
done

if [ "$fail" -eq 0 ]; then
	echo "${health_check} is ok"
else
	echoerr "${health_check} is not ok (${fail} of ${iters} failed)"
fi
errs=$((errs+fail))

######################
# stream API, no auth
######################
echo
fail=0
health_check="Telemetry api stream (no authn)"
echo "curl -s ${url}/stream"

for i in $(seq 1 $iters);
do
	res=$(curl -s ${url}/stream)
	if [ "$?" -ne 0 ]; then
		fail=$((fail+1))
	fi
done

if [ "$fail" -eq 0 ]; then
	echo "${health_check} is ok"
else
	echoerr "${health_check} is not ok (${fail} of ${iters} failed)"
fi
errs=$((errs+fail))


######################
# ping API, auth
######################
echo
fail=0
health_check="Telemetry api ping (auth)"
echo "curl -s -k -H \"Accept: application/json\" -H \"Authorization: Bearer ${auth_token}\" ${url}/ping"

for i in $(seq 1 $iters);
do
	res=$(curl -s -k -H "Accept: application/json" -H "Authorization: Bearer ${auth_token}" ${url}/ping)
	if [ "$?" -ne 0 ]; then
		fail=$((fail+1))
	fi
done

if [ "$fail" -eq 0 ]; then
	echo "${health_check} is ok"
else
	echoerr "${health_check} is not ok (${fail} of ${iters} failed)"
fi
errs=$((errs+fail))

######################
# stream API, auth
######################
echo
fail=0
health_check="Telemetry api stream (auth)"
echo "curl -s -k -H 'Accept: application/json' -H \"Authorization: Bearer ${auth_token}\" ${url}/stream"

for i in $(seq 1 $iters);
do
	res=$(curl -s -k -H 'Accept: application/json' -H "Authorization: Bearer ${auth_token}" ${url}/stream)
	if [ "$?" -ne 0 ]; then
		fail=$((fail+1))
	fi
done

if [ "$fail" -eq 0 ]; then
	echo "${health_check} is ok"
else
	echoerr "${health_check} is not ok (${fail} of ${iters} failed)"
fi

###########################
# ping API, invalid auth
##########################
echo
fail=0
health_check="Telemetry api ping (invalid auth)"
echo ="curl -s -k -H 'Accept: application/json' -H \"Authorization: Bearer ${invalid_auth_token}\" ${url}/ping"

for i in $(seq 1 $iters);
do
	res=$(curl -s -k -H 'Accept: application/json' -H "Authorization: Bearer ${invalid_auth_token}" ${url}/ping)
	if [ "$?" -ne 0 ]; then
		fail=$((fail+1))
	fi
done

if [ "$fail" -eq 0 ]; then
	echo "${health_check} is ok"
else
	echoerr "${health_check} is not ok (${fail} of ${iters} failed)"
fi
errs=$((errs+fail))

###########################
# stream API, invalid auth
##########################
echo
fail=0
health_check="Telemetry api stream (invalid auth)"
echo "curl -s -k -H 'Accept: application/json' -H \"Authorization: Bearer ${invalid_auth_token}\" ${url}/stream"

for i in $(seq 1 $iters);
do
	res=$(curl -s -k -H 'Accept: application/json' -H "Authorization: Bearer ${invalid_auth_token}" ${url}/stream)
	if [ "$?" -ne 0 ]; then
		fail=$((fail+1))
	fi
done

if [ "$fail" -eq 0 ]; then
	echo "${health_check} is ok"
else
	echoerr "${health_check} is not ok (${fail} of ${iters} failed)"
fi
errs=$((errs+fail))

echo
if [ "$errs" -eq 0 ]; then
	echo "Telemetry API looks healthy"
else
	echoerr "Telemetry API is not healthy"
fi

exit ${errs}

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
