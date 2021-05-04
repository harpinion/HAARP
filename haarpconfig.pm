#!/usr/bin/perl
###############################################################################
#
# HAARP Scanner configuration
# http://sourceforge.net/projects/haarpscan/
#
# Copyright 2017 by Tadeus
#
###############################################################################
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
# 
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
# 
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
###############################################################################
# Global Parameters
###############################################################################

package haarpconfig;
use strict;
use warnings;

our $Interval = 5;						# Interval for measurement cycle in minutes (2 - 30)
our $LogFile = "/srv/SDR/haarp.log";		# Path and filename of logfile
our $Archive = "/srv/SDR/archive";			# Path for archive of files / data
our $PicFormat = "png";					# Format for heatmap pictures png or jpg


###############################################################################
# Scan parameters
# To add ranges just copy and edit a complete { section }
# Set 'active => 0' to deactivate a range
# 'seconds' should be a minimum of 10 for the time annotations
###############################################################################

our @Scan = (
	{	# Range Description
	title 		=> "0.5 MHz - 5 MHz",
	freq_from		=> "125.5M",
	freq_to		=> "130.3M",
	freq_offset	=> "-125000000",
	freq_step		=> "1k",
	gain			=> "5",
	seconds		=> "10",
	path_name		=> "/srv/SDR/tmp/Area_2MHz_",
	path_daily	=> "/srv/SDR/daily/0002_MHz",
	active => 	1
	},        	
	{	# Range Description
	title 		=> "5 MHz - 10 MHz",
	freq_from		=> "130.3M",
	freq_to		=> "135M",
	freq_offset	=> "-125000000",
	freq_step		=> "1k",
	gain			=> "5",
	seconds		=> "10",
	path_name		=> "/srv/SDR/tmp/Area_7MHz_",
	path_daily	=> "/srv/SDR/daily/0007_MHz",
	active => 	1
	},        	
	{	# Range Description
	title 		=> "59 MHz - 70 MHz",
	freq_from		=> "59M",
	freq_to		=> "70M",
	freq_step		=> "5k",
	gain			=> "5",
	seconds		=> "10",
	path_name		=> "/srv/SDR/tmp/Area_060MHz_",
	path_daily	=> "/srv/SDR/daily",
	active => 	0
	},        	
	{	# Range Description
	title 		=> "119.5 MHz - 120.5 MHz",
	freq_from		=> "119.5M",
	freq_to		=> "120.5M",
	freq_step		=> "1k",
	gain			=> "5",
	seconds		=> "10",
	path_name		=> "/srv/SDR/tmp/Area_120MHz_",
	path_daily	=> "/srv/SDR/daily/0120_MHz",
	active => 	0
	},        	
	{	# Range Description
	title 		=> "148.8 MHz - 170.7 MHz",
	freq_from		=> "148.8M",
	freq_to		=> "170.7M",
	freq_step		=> "10k",
	gain			=> "5",
	seconds		=> "10",
	path_name		=> "/srv/SDR/tmp/Area_160MHz_",
	path_daily	=> "/srv/SDR/daily/0170_MHz",
	active => 	0
	},  
	{	# Range Description
	title 		=> "239.5 MHz - 240.5 MHz",
	freq_from		=> "239.5M",
	freq_to		=> "240.5M",
	freq_step		=> "1k",
	gain			=> "5",
	seconds		=> "10",
	path_name		=> "/srv/SDR/tmp/Area_240MHz_",
	path_daily	=> "/srv/SDR/daily/0240_MHz",
	active => 	0
	},        	
	{	# Range Description
	title 		=> "249.5 MHz - 250.5 MHz",
	freq_from		=> "249.5M",
	freq_to		=> "250.5M",
	freq_step		=> "1k",
	gain			=> "5",
	seconds		=> "10",
	path_name		=> "/srv/SDR/tmp/Area_250MHz_",
	path_daily	=> "/srv/SDR/daily/0250_MHz",
	active => 	0
	},        	
	{	# Range Description
	title 		=> "479.2 MHz - 480.8 MHz",
	freq_from		=> "479.2M",
	freq_to		=> "480.8M",
	freq_step		=> "1k",
	gain			=> "5",
	seconds		=> "10",
	path_name		=> "/srv/SDR/tmp/Area_480MHz_",
	path_daily	=> "/srv/SDR/daily/0480_MHz",
	active => 	0
	},        	
	{	# Range Description
	title 		=> "719 MHz - 721 MHz",
	freq_from		=> "719M",
	freq_to		=> "721M",
	freq_step		=> "1k",
	gain			=> "5",
	seconds		=> "10",
	path_name		=> "/srv/SDR/tmp/Area_720MHz_",
	path_daily	=> "/srv/SDR/daily/0720_MHz",
	active => 	0
	},
	{	# Range Description
	title 		=> "959 MHz - 961 MHz",
	freq_from		=> "959M",
	freq_to		=> "961M",
	freq_step		=> "1k",
	gain			=> "5",
	seconds		=> "10",
	path_name		=> "/srv/SDR/tmp/Area_960MHz_",
	path_daily	=> "/srv/SDR/daily/0960_MHz",
	active => 	0
	},
);
