#!/bin/sh
###############################################################################
#
# haarpscan image piecing
# this script executes haarpscan.pl as user haarp
#
# V 1.0 vom 21.04.2017
#
# Copyright 2017 by Tadeus
#
###############################################################################

cd /srv/SDR
sudo -u haarp /usr/bin/perl haarpscan.pl -p
