#!/bin/bash
# set -x

# 

BINPATH=`dirname "$0"`

# Steady rate of messages on two compute nodes
$BINPATH/tcpflood_steady_on_computes.sh 2 86400
