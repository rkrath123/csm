#!/bin/bash
# set -x

BINPATH=`dirname "$0"`

# Burst of messages on one compute node
$BINPATH/tcpflood_burst_on_computes.sh 1
