#!/bin/bash
# set -x

BINPATH=`dirname "$0"`

# Burst of messages on four compute nodes
$BINPATH/tcpflood_burst_on_computes.sh 4
