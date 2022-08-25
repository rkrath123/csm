#!/bin/bash
# set -x

# 

BINPATH=`dirname "$0"`

# Steady rate of messages on one compute node
$BINPATH/tcpflood_steady_on_computes.sh 1 86400
