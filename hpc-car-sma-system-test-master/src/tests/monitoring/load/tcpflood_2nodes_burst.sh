#!/bin/bash
# set -x

BINPATH=`dirname "$0"`

# Burst of messages on two compute nodes
$BINPATH/tcpflood_burst_on_computes.sh 2
