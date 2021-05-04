#!/bin/sh
###############################################################################
#
# haarpscan daemon starter
#
# V 1.0 vom 16.04.2017
#
# Copyright 2017 by Tadeus
#
###############################################################################

cd /srv/SDR
nohup /usr/bin/perl haarpscan.pl -d -l &>/dev/null &
