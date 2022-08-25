#!/bin/bash
# set -x

# 

BINPATH=`dirname "$0"`

# Steady rate of messages on four compute nodes
$BINPATH/tcpflood_steady_on_computes.sh 4 86400
