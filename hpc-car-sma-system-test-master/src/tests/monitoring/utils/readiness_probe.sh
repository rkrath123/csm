#! /bin/bash
# set -x

# Readiness probe.  Is the SMA environment ready for testing?
# Currently just a sleep.  Should be improved.

initial_delay_secs=300

start_time=$(date +'%s')
echo "Starting readiness probe at `date`"
sleep ${initial_delay_secs}
date
echo "done in $(($(date +'%s') - $start_time)) seconds"

exit 0

# vim:shiftwidth=4:softtabstop=4:tabstop=4:

