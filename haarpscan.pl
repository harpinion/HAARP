#!/usr/bin/perl
###############################################################################
#
# HAARP Scanner
# http://sourceforge.net/projects/haarpscan/
#
# This script uses the command rtl_power of Gnu Radio to observe and report
# multiple frequency ranges to detect HAARP activity.
# The scanner can work with every SDR receiver like an cheap RTL-SDR:
# http://www.rtl-sdr.com/about-rtl-sdr/
#
# This scanner is able to scan different frequency ranges in sequence.
# All ranges are defined in the section 'Scan parameters' below.
# The scans will be done in a fixed time interval like 10 minutes.
# A heatmap is generated each time and will be pieced together
# to a complete waterfall picture at the end of the day.
# 
# For running heatmap.py python and the package python-imaging is needed.
# The resulting pictures are pieced together with imagemagick.
# Thanks to Kyle Keen for his work! http://kmkeen.com/rtl-power/
#
# For a simulation run showing the console commands run 'haarpscan.pl -t -s -b 2'
# For normal execution as daemon run 'haarpscan.pl -d -l'
#
# Best view of the source code with 5 spaces for each tab. Encoded in UTF-8
#
# V 0.5 vom 14.04.2017 Initial tests and functions
# V 0.6 vom 16.04.2017 Piecing images together with imagemagick
# V 0.7 vom 16.04.2017 Added time annotations to the daily heatmaps
# V 0.8 vom 16.04.2017 Added daily cleanup jobs
# V 0.9 vom 17.04.2017 Some manual options and outsourcing configuration
# V 1.0 vom 30.07.2017 Added optional frequency offset, picture format and reprocessing
# V 1.1 vom 26.08.2017 Added directory creation for ranges in range list
# V 1.2 vom 22.03.2020 Added calculation of week
# V 1.3 vom 10.08.2020 Added creation of weekly files
#
# Copyright 2017 - 2020 by tadeus
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

require 5.008;
# use 5.010;
use strict;
use warnings;
use File::Basename;

use Time::Local;
use POSIX qw(strftime);

use lib "/srv/SDR";		# If local path is not included http://perldoc.perl.org/perlrun.html#ENVIRONMENT
use haarpconfig;

my $DLevel = 1;		# Debug Level, 0 = No output, 1 = Normal Output, 2-4 Enhanced Output
my $Version = "V 1.3";

my $BinRTL = "/usr/bin/rtl_power";					# Path to installed rtl_power
my $BinIdentity = "/usr/bin/identify";				# Path to installed identify of imagemagick
my $BinConvert = "/usr/bin/convert";				# Path to installed convert of imagemagick
my $BinTar = "/bin/tar";							# Path to installed tar for packing files
my $BinRm = "/bin/rm";							# Path to installed rm after packing files
my $BinHeat = "/usr/bin/python /srv/SDR/heatmap.2.py";	# Path to modified heatmap script


###############################################################################
# Variable declaration
###############################################################################

my $ScanCount;									# Number of scans to do
my $ScanCounter = 0;							# Number of scans done
my $LastDay = 0;								# For detection of a new day
my $FlagScan = 0;								# Flag for locking run
my $CSVFile = "";								# CSV file to analyze
my $Path2MHz = "";								# Path for daily 2 MHz-files (option -w)
my $Path7MHz = "";								# Path for daily 7 MHz-files (option -w)
my $WeekTmp = "/tmp/";							# Path for temporary files / weekly pictures

# Just import the needed configuration data
my @Scan = @haarpconfig::Scan;
my $Interval = $haarpconfig::Interval;				# Interval for measurement cycle in minutes (2 - 30)
my $LogFile = $haarpconfig::LogFile;				# Path and filename of logfile
my $Archive = $haarpconfig::Archive;				# Path for archive of files / data
my $PicFormat = $haarpconfig::PicFormat;			# Format for heatmap pictures png or jpg


###############################################################################
# Check commandline parameters
###############################################################################

# program options
my $option;
my $opt_daemon = 0;
my $opt_range = 0;
my $opt_test = 0;
my $opt_log = 0;
my $opt_mysql = 0;
my $opt_piece = 0;
my $opt_piece_d = 0;
my $opt_clean = 0;
my $opt_week = 0;
my $opt_sim = 0;
my $opt_reprocess = "";

if (@ARGV == 0) {		# no paramter -> instructions
	print "\n";
	print "HAARP-Scan $Version\n";
	print "haarpscan.pl [option]\n";
	print "             -d daemon mode\n";
	print "             -t single test run\n";
	print "             -l with logfile\n";
	print "             -r range list and directory creation\n";
	print "             -p piece together heatmaps \n";
	print "             -q piece together heatmaps and delete (daily job)\n";
	print "             -u cleanup files (daily job)\n";
	print "             -w [path 2 MHz] [path 7 MHz] piece together weekly heatmaps\n";
	print "             -s simulate without execution for debugging\n";
# 	print "             -m MySQL data capture (future)\n";
	print "             -c [file] analyze csv file\n";
	print "             -a [path] reprocess csv data in path\n";
	print "             -b [level] debug\n";
	print "\n";

	exit;
}
if (@ARGV > 7) { die "To many parameters!\n"; }

OPTION: 	
while ( defined( $option = shift(@ARGV) )) {
	$_ = $option;
	/^-d$/ && do { $opt_daemon = 1; next OPTION; };
	/^-t$/ && do { $opt_daemon = 0; next OPTION; };
	/^-l$/ && do { $opt_log = 1; next OPTION; };
	/^-m$/ && do { $opt_mysql = 1; next OPTION; };
	/^-r$/ && do { $opt_range = 1; next OPTION; };
	/^-p$/ && do { $opt_piece = 1; next OPTION; };
	/^-q$/ && do { $opt_piece_d = 1; next OPTION; };
	/^-u$/ && do { $opt_clean = 1; next OPTION; };
	/^-w$/ && do { $opt_week = 1; $Path2MHz = shift(@ARGV); $Path7MHz = shift(@ARGV); next OPTION; };
	/^-c$/ && do { $CSVFile = shift(@ARGV); next OPTION; };
	/^-s$/ && do { $opt_sim = 1; next OPTION; };
	/^-a$/ && do { $opt_reprocess = shift(@ARGV); next OPTION; };
	/^-b$/ && do { $DLevel = shift(@ARGV); next OPTION; };
	/^-.*/ && die "Illegal option: '$option' !\n";
}

if ($DLevel < 0) { $DLevel = 0; }
if ($DLevel > 3) { $DLevel = 3; }


main:
###############################################################################
# Main programm
###############################################################################

# trap ctrl+c here.
$SIG{'INT'} = sub { 
	$DLevel > 0 && print "\n";
	LogPrint("Shutting down haarpscan by SIGINT");
	if ($opt_log) {close(LOut);}
	exit 0;
};

$ScanCount = @Scan;
if ($opt_range) {
	ScanList();
	exit 0;
}
if ($opt_piece) {
	DailyHeatmap(0);
	exit 0;
}
if ($opt_piece_d) {
	DailyHeatmap(1);
	exit 0;
}
if ($opt_reprocess ne "") {
	ReprocessCSV();
	exit 0;
}
if ($opt_clean) {
	DailyCleanup();
	exit 0;
}
if ($opt_week) {
	ProcessWeekmap();
	exit 0;
}
if ($CSVFile ne "") {
	CsvAnalyze($CSVFile);
	exit 0;
}

if ($opt_log) { 
	open(LOut, ">> $LogFile") or die "ERROR opening logfile '$LogFile': $!\n";
	select((select(LOut), $| = 1)[0]);		# set nonbufferd mode
}

if ($opt_daemon) {
	$DLevel > 0 && print "\n";
	LogPrint("Starting haarpscan $Version in daemon mode");
} else {
	$DLevel > 0 && print "\n";
	LogPrint("\nStarting haarpscan $Version single run\n");
}


############################### Daemon Mainloop ###############################
do {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$ydat,$isdst) = localtime();
	if ($LastDay == 0) {
		$LastDay = $mday;
	}
	
	if (($min % $Interval == 0 && $sec < 30 && $FlagScan == 0) || $opt_daemon == 0) {	# Every 10 Min.
		$ScanCounter ++;
		$DLevel > 0 && print "\n";
		LogPrint("Running scan number $ScanCounter");
		$DLevel > 0 && print "\n";
		
		for(my $sa = 0; $sa < $ScanCount; $sa ++) {				# For each frequency range
			if ($Scan[$sa]->{'active'}) {
# 				LogPrint("Scanning " . $Scan[$sa]->{'title'});	# Uncomment for detail logging
				$DLevel > 0 && print "Scanning " . $Scan[$sa]->{'title'} . "\n";
				my $timestamp = DateTime("i");

				# Scan
				my $command = $BinRTL . " -f " . $Scan[$sa]->{'freq_from'} . ":" . $Scan[$sa]->{'freq_to'} . ":" . $Scan[$sa]->{'freq_step'};
				$command   .= " -g " . $Scan[$sa]->{'gain'} . " -i 1s -e " . $Scan[$sa]->{'seconds'};
				$command   .= "s -w hann-poisson " . $Scan[$sa]->{'path_name'} . "$timestamp.csv";
				$DLevel > 1 && print "RTL : '$command'\n";
				SysExec($command);

				# Create heatmap
				$command = $BinHeat . " --palette charolastra ";
				if (exists $Scan[$sa]->{'freq_offset'}) {		# Add frequency offset if it exists
					$command .= "--offset " . $Scan[$sa]->{'freq_offset'} . " ";
				}
				$command .= $Scan[$sa]->{'path_name'} . "$timestamp.csv " . $Scan[$sa]->{'path_name'} . "$timestamp." . $PicFormat;
				$DLevel > 1 && print "HEAT: '$command'\n\n";
				SysExec($command);
			}
		}
		$FlagScan = 1;
	}
	
	if ($LastDay != $mday) {							# Every new day after 0:00
		DailyHeatmap(1);
		DailyCleanup();
		$LastDay = $mday;
	}
	
	if ($sec >= 58) {								# Reset flag
		$FlagScan = 0;
	}
	select(undef, undef, undef, 0.5);					# Sleep for 500 ms
} while $opt_daemon;

if ($opt_log) {close(LOut);}
exit 0;


###############################################################################
# Reprocess heatmaps from CSV files
###############################################################################

sub ReprocessCSV {
	my $HeatmapCount = 0;

	$DLevel > 0 && print "Reprocessing is an experimental feature!\n";
	$DLevel > 0 && print "It works only with csv files of one scan type in the given path!\n\n";

	if (substr($opt_reprocess, -1, 1) ne "/") { $opt_reprocess .= "/"; }
	push @Scan, {		# Add new Element for this run / Parameters must be defined correct here
		title 		=> "Reprocessing",
		freq_offset	=> "-125000000",
		seconds		=> "10",
		path_name		=> $opt_reprocess,
		path_daily	=> $opt_reprocess,
		active => 	1
	};

	my $filesearch = $opt_reprocess . "*.csv";
	my @files = glob $filesearch;
	my $filecount = @files;
	if ($filecount < 2) {								# Nothing to do
		$DLevel > 0 && print "Warning! There are only $filecount csv files for '$filesearch'\n";
		return;
	}
	$DLevel > 0 && print "Found $filecount files: $filesearch\n";

	for my $file (@files) {								# For each file
		my $command = $BinHeat . " --palette charolastra ";	# Create heatmap
		if (exists $Scan[$ScanCount]->{'freq_offset'}) {		# Add frequency offset if it exists
			$command .= "--offset " . $Scan[$ScanCount]->{'freq_offset'} . " ";
		}
		$command .= $file . " " . substr($file, -90, -3) . $PicFormat . " > /dev/null";
		$DLevel > 1 && print "HEAT: '$command'\n\n";
		SysExec($command);
		$HeatmapCount ++;
	}
	$DLevel > 0 && print "$HeatmapCount CSV files processed and heatmap images created.\n";
	
	$HeatmapCount = ProcessHeatmap($ScanCount, 0);
	$DLevel > 0 && print "$HeatmapCount heatmap images pieced together.\n";
}


###############################################################################
# Create daily heatmap images
###############################################################################

sub DailyHeatmap {
	my $delete = $_[0];								# 1 for daily job with delete of the single heatmap pictures

	my $HeatmapCount = 0;

	$DLevel > 0 && print "\n";
	LogPrint("Piecing together heatmap images");

	for(my $sa = 0; $sa < $ScanCount; $sa ++) {			# For each frequency range
		if ($Scan[$sa]->{'active'}) {
			$HeatmapCount += ProcessHeatmap($sa, $delete);
		}
	}
	if ($delete) {
		LogPrint("$HeatmapCount heatmap images processed and deleted");
	} else {
		LogPrint("$HeatmapCount heatmap images processed");
	}
}


###############################################################################
# Piece together heatmap images
###############################################################################

sub ProcessHeatmap {
	my $scannr     = $_[0];							# number of scan parameter
	my $delete     = $_[1];							# 1 for daily job with delete of the single heatmap pictures

	$DLevel > 0 && print "\n";

	my $filesearch = $Scan[$scannr]->{'path_name'} . "*." . $PicFormat;
	my @files = glob $filesearch;
	my $filecount = @files;
	if ($filecount < 2) {							# Nothing to do
		LogPrint("Warning! There are only $filecount pictures for '$filesearch'");
		return $filecount;
	}
	$DLevel > 0 && print "Found $filecount files: $filesearch\n";
	my @sorted = sort { $b cmp $a } @files;				# Reverse order needed

	if (not exists $Scan[$scannr]->{'width'}) {				# Estimate picture size if unknown
		# https://www.imagemagick.org/script/identify.php
		my $res = `$BinIdentity $files[0]`;
		$DLevel > 2 && print "Resolution: $res";
		if ($PicFormat eq "jpg") {
			$res =~ /.+jpg JPEG (\d+)x(\d+)/;
			if (defined $1) {
				$Scan[$scannr]->{'width'} = $1;
				$Scan[$scannr]->{'height'} = $2;
			} else {
				LogPrint("ERROR - Picture size could not be estimated! '$res'");
				next;
			}
		} else {
			$res =~ /.+png PNG (\d+)x(\d+)/;
			if (defined $1) {
				$Scan[$scannr]->{'width'} = $1;
				$Scan[$scannr]->{'height'} = $2;
			} else {
				LogPrint("ERROR - Picture size could not be estimated! '$res'");
				next;
			}
		}
		$DLevel > 1 && print "Picture width " . $Scan[$scannr]->{'width'} . " & height " . $Scan[$scannr]->{'height'} . "\n";
	}

	# Piecing the images together
	# https://www.imagemagick.org/script/index.php
	# http://www.imagemagick.org/Usage/layers/#layers
	# convert -page 1025x56+0+20 A3.png -page +0+10 A2.png -page +0+0 A1.png -layers flatten output.png
	my $timespace = 30;								# Indentation for time marker

	my $filename = basename $files[0];
	my $datestamp = substr($filename, -23, 10);			# Extract date from filename
	my $daymonth = substr($datestamp, 8, 2) . substr($datestamp, 4, 3);
	my $dayyear  = substr($datestamp, 0, 4);			# Date for daily picture
	
	$filename = basename $Scan[$scannr]->{'path_name'};
	my $tmpname = $Scan[$scannr]->{'path_daily'} . "/$filename$datestamp.tmp." . $PicFormat;	# For daily picture without annotations
	
	my $command = $BinConvert . " -page " . ($Scan[$scannr]->{'width'} + $timespace) . "x" . ($Scan[$scannr]->{'height'} + ($filecount - 1) * $Scan[$scannr]->{'seconds'});
	$command .= "+$timespace+" .  (($filecount - 1) * $Scan[$scannr]->{'seconds'});
	my $offset = ($filecount - 1) * $Scan[$scannr]->{'seconds'};			# Offset for 2nd picture

	# Creating time annotations
	# http://www.imagemagick.org/script/command-line-options.php?#annotate
	# convert test.png -fill white -pointsize 10 -annotate +0+36 '14:10' -annotate +0+46 '14:20' output.png
	my $annotation = "$BinConvert $tmpname -fill white -pointsize 10";
	$annotation .= " -annotate +0+10 '$daymonth' -annotate +0+20 '$dayyear'";
	
	my $piccount = 0;
	for my $file (@sorted) {							# For each file
		$DLevel > 2 && print "- $file\n";
		$piccount ++;
		if ($piccount == 1) {
			$command .= " $file";
		} else {
			$offset -= $Scan[$scannr]->{'seconds'};		# Offset for each picture
			$command .= " -page +$timespace+$offset $file"; 
		}
		# Creating annotation
		$filename = basename $file;
		my $timestamp = substr($filename, -12, 2) . ":" . substr($filename, -9, 2);	# Extract time from filename
		$annotation .= " -annotate +0+" . (($filecount - $piccount) * $Scan[$scannr]->{'seconds'} + 36) . " '$timestamp'";
	}

	$command .= " -background black -layers flatten $tmpname";	# Pieced file
	$DLevel > 1 && print "CONVERT piecing: '$command'\n\n";
	my $res = SysExec($command);
	if ($res != 0) {
		LogPrint("ERROR piecing the images! Command: '$command'");
		next;
	} else {										# The single heatmap pictures can be deleted now
		if ($delete) {
			$command = $BinRm . " -f " . $Scan[$scannr]->{'path_name'} . "*." . $PicFormat;
			my $res = SysExec($command);
			if ($res != 0) {
				LogPrint("ERROR deleting the single heatmap files! Command: '$command'");
			}
		}
	}

	if ($Scan[$scannr]->{'title'} eq "Reprocessing") {	# Pathname for reprocessed file
		$filename = "Reprocessing_";
	} else {
		$filename = basename $Scan[$scannr]->{'path_name'};	# Annotated file
	}
	$annotation .= " " . $Scan[$scannr]->{'path_daily'} . "/$filename$datestamp." . $PicFormat;
	$DLevel > 1 && print "CONVERT annotation: '$annotation'\n\n";
	$res = SysExec($annotation);
	if ($res != 0) {
		LogPrint("ERROR creating time annotations! Command: '$annotation'");
		next;
	} else {
		$command = $BinRm . " -f " . $tmpname;			# Remove temporary picture without annotations
		my $res = SysExec($command);
	}
	return $filecount;
}


###############################################################################
# Piece together heatmap images to a week overview
# convert Area.png -resize 960x337 Area.s.png
# convert -size 1920x2359 xc:black black.png
###############################################################################

sub ProcessWeekmap {
	my $scannr = 0;
	my $LastWeek;
	my $day;
	my $month;
	my $year;
	my $FirstDay;
	my $FirstMonth;
	my $LastDay;
	my $LastMonth;
	my $FileCounter = 0;
	my $AnnoDate;
	my $AnnoFile;
	my $DayCount = 0;
	my $Piecing = $BinConvert . " -page 1920x2359";
	
	$DLevel > 0 && print "\n";
	if (! -d $Path2MHz) {
		$DLevel > 0 && print "Path for 2 MHz-files does not exist!\n";
		exit 1;
	}
	if (! -d $Path7MHz) {
		$DLevel > 0 && print "Path for 7 MHz-files does not exist!\n";
		exit 1;
	}

	my $filesearch = $Path2MHz . "/*." . $PicFormat;
	my @files2 = glob $filesearch;
	my $filecount2 = @files2;
	if ($filecount2 < 1) {							# Nothing to do
		$DLevel > 0 && print "Warning! There are no pictures for '$filesearch'\n";
		exit 1;
	} else {
		$DLevel > 0 && print "Found $filecount2 files for 2 MHz with $filesearch\n";
	}
	$filesearch = $Path7MHz . "/*." . $PicFormat;
	my @files7 = glob $filesearch;
	my $filecount7 = @files7;
	if ($filecount7 < 1) {							# Nothing to do
		$DLevel > 0 && print "Warning! There are no pictures for '$filesearch'\n";
		exit 1;
	} else {
		$DLevel > 0 && print "Found $filecount7 files for 7 MHz with $filesearch\n";
	}
	if ($filecount2 != $filecount7) {
		$DLevel > 0 && print "Warning! Count of file mismatch!\n";
		exit 1;
	}

	my @sorted2 = sort { $a cmp $b } @files2;				# sorted order needed
	my @sorted7 = sort { $a cmp $b } @files7;				# sorted order needed

	for my $file (@sorted2) {							# For each file
		my $filename = basename $file;
		my $datestring = substr($filename, -14, 10);			# Extract date from filename
		$year = substr($filename, -14, 4);
		$month = substr($filename, -9, 2);
		$day = substr($filename, -6, 2);
		if ($FileCounter == 0) {							# Start-Date
			$FirstDay = $day;
			$FirstMonth = $month;
		}
		
		my $epoch = timelocal(0, 0, 0, $day, $month - 1, $year - 1900);
		my $week = strftime("%U", localtime($epoch)) + 1;
		if ($FileCounter == 0) { $LastWeek = $week; }
		############################## New week ##############################
		if ($week != $LastWeek) {
			my $WeekName = "Week." . $year . ".";						# Create Filename for week
			if ($LastWeek < 10) { $WeekName .= "0"; }
			$WeekName .= "$LastWeek-$FirstDay.$FirstMonth-$LastDay.$LastMonth";
			$FirstDay = $day;
			$FirstMonth = $month;
			$DLevel > 0 && print "Processing week $LastWeek ...\n\n";
			
			$Piecing .= " -background black -layers flatten $WeekName.png";		# Piecing file for the week
			$DLevel > 1 && print "PIECING week: '$Piecing'\n\n";
			my $res = SysExec($Piecing);
			if ($res == 0) {
				my $remove = $BinRm . " " .  $WeekTmp . "Area*";
				$res = SysExec($remove);
				$Piecing = $BinConvert . " -page 1920x2359";
				$DayCount = 0;
			} else {
				$DLevel > 0 && print "ERROR piecing week picture $WeekName.png !\n";
				exit 1;
			}

			$AnnoFile = $BinConvert . " $WeekName.png -fill white -pointsize 12" . $AnnoDate . " $WeekName.jpg";
			$DLevel > 1 && print "ANNOTATING week: '$AnnoFile'\n\n";
			$res = SysExec($AnnoFile);
			if ($res == 0) {
				my $remove = $BinRm . " $WeekName.png";
				$res = SysExec($remove);
				$AnnoDate = "";
			} else {
				$DLevel > 0 && print "ERROR annotating week picture $WeekName.png !\n";
				exit 1;
			}
			$LastWeek = $week;
		} else {
			$LastDay = $day;
			$LastMonth = $month;
		}
		
 		$DLevel > 0 && print "Processing $day.$month.$year in week $week ...\n";
 		my $command = $BinConvert . " " . $file . " -resize 960x337 " . $WeekTmp . $filename;
 		$DLevel > 1 && print "RESIZE 2 week: '$command'\n";
 		my $res = SysExec($command);
 		if ($res == 0) {
			if ($DayCount == 0) {
				$Piecing .= "+0+0 " . $WeekTmp . $filename;
			} else {
				$Piecing .= " -page +0+" . $DayCount * 337 . " " . $WeekTmp . $filename;
			}
			$AnnoDate .= " -annotate +10+" . ($DayCount * 337 + 20) . " '$day.$month.$year'";
 		} else {
			$DLevel > 0 && print "ERROR resizing picture " . $file .  " !\n";
 		}
 		$command = $BinConvert . " " . $sorted7[$FileCounter] . " -resize 960x337 " . $WeekTmp . basename $sorted7[$FileCounter];
 		$DLevel > 1 && print "RESIZE 7 week: '$command'\n\n";
 		$res = SysExec($command);
 		if ($res == 0) {
			$Piecing .= " -page +960+" . $DayCount * 337 . " " . $WeekTmp . basename $sorted7[$FileCounter];
			$DayCount ++;
 		} else {
			$DLevel > 0 && print "ERROR resizing picture " . $sorted7[$FileCounter] .  " !\n";
 		}

		$FileCounter ++;
	}
	my $WeekName = "Week." . $year . ".";						# Processing the rest of the days
	if ($LastWeek < 10) { $WeekName .= "0"; }
	$WeekName .= "$LastWeek-$FirstDay.$FirstMonth-$LastDay.$LastMonth";
	$DLevel > 0 && print "Processing week $LastWeek ...\n\n";
	
	$Piecing .= " -background black -layers flatten $WeekName.png";	# Piecing file for the week
	$DLevel > 1 && print "PIECING week: '$Piecing'\n\n";
	my $res = SysExec($Piecing);
	if ($res == 0) {
		my $remove = $BinRm . " " .  $WeekTmp . "Area*";
		$res = SysExec($remove);
	} else {
		$DLevel > 0 && print "ERROR piecing week picture $WeekName.png !\n";
		exit 1;
	}

	$AnnoFile = $BinConvert . " $WeekName.png -fill white -pointsize 12" . $AnnoDate . " $WeekName.jpg";
	$DLevel > 1 && print "ANNOTATING week: '$AnnoFile'\n\n";
	$res = SysExec($AnnoFile);
	if ($res == 0) {
		my $remove = $BinRm . " $WeekName.png";
		$res = SysExec($remove);
	} else {
		$DLevel > 0 && print "ERROR annotating week picture $WeekName.png !\n";
		exit 1;
	}
}


###############################################################################
# Daily file cleanup
###############################################################################

sub DailyCleanup {
	my $TarCount = 0;

	$DLevel > 0 && print "\n";
	LogPrint("Daily file cleanup");

	for(my $sa = 0; $sa < $ScanCount; $sa ++) {				# For each frequency range
		if ($Scan[$sa]->{'active'}) {
			my $filesearch = $Scan[$sa]->{'path_name'} . "*.csv";
			my @files = glob $filesearch;
			my $filecount = @files;
			if ($filecount < 1) {							# Nothing to do
				LogPrint("Warning! There are no csv files for '$filesearch'");
				next;
			}
			my $filename = basename $files[0];
			my $datestamp = substr($filename, -23, 10);			# Extract date from filename
			$DLevel > 0 && print "Found $filecount files: $filesearch\n";
			
			$filename = basename $Scan[$sa]->{'path_name'};
			my $command = $BinTar . " cfJ $Archive/$filename$datestamp.csv.tar.xz " . $Scan[$sa]->{'path_name'} . "*.csv";
			$DLevel > 1 && print "TAR : '$command'\n";
			my $res = SysExec($command);
			if ($res == 0) {
				$TarCount += $filecount;
				$command = $BinRm . " -f " . $Scan[$sa]->{'path_name'} . "*.csv";
				my $res = SysExec($command);
				if ($res != 0) {
					LogPrint("ERROR deleting the csv files! Command: '$command'");
				}
			} else {
				LogPrint("ERROR taring the csv files! Command: '$command'");
			}
		}
	}
	LogPrint("$TarCount csv files archived and deleted");
}


###############################################################################
# Read and analyze CSV-File
###############################################################################

sub CsvAnalyze {
	my $ReadFile = $_[0];
	
	my $values;
	my $line;
	my $lcount = 0;
	
	$DLevel > 0 && print "This is an experimental feature for future analysis!\n";
	$DLevel > 0 && print "Maybe the code is already useful for somebody.\n";

	# format: date, time, Hz low, Hz high, Hz step, samples, dB, dB, dB, ...
	if (-e $ReadFile) {
		open(FILE, $ReadFile) or die "Error opening of '$ReadFile': $!\n";
		while(<FILE>) {
			chomp;
			$line = $_;
			$lcount ++;
			if ($lcount == 1) {
				my $vmin = 1e99;
				my $vmax = -1e99;
				my $vcount = 0;
				my $vaverage = 0;
				my @data = split(", ", $line);
				$values = @data;
				my $timestamp = $data[0] . " " . $data[1];
				for(my $fs = 6; $fs < $values; $fs ++) {					# For each value
					$vaverage += $data[$fs];
					if ($data[$fs] < $vmin) {$vmin = $data[$fs];}
					if ($data[$fs] > $vmax) {$vmax = $data[$fs];}
				}
				$vaverage /= ($values - 6);
				$DLevel > 0 && print "\n$timestamp from " . ($data[2] / 1e6) . " MHz to " . ($data[3] / 1e6) . " step " . ($data[4] / 1e3) .
					" KHz  Min. $vmin dB  Max. $vmax dB  Avg. " . round($vaverage, 2) . " dB\n";

				my $vstandard = 0;
				for(my $fs = 6; $fs < $values; $fs ++) {					# For each value
					$vstandard += ($data[$fs] - $vaverage) ** 2;
				}
				$vstandard /= ($values - 6);
				$vstandard = $vstandard ** 0.5;
				$DLevel > 1 && print "Standard deviation " . round($vstandard, 2) . "\n";

				my @vfreq;
				my @vcarrier;
				my $vslope = 1;
				my $vfrequency = $data[2];
				for(my $fs = 9; $fs < $values; $fs ++) {					# For each value
					if ($data[$fs] < $data[$fs - 1] && $vslope == 1) {		# inversion falling
						if ($data[$fs - 1] - $data[$fs - 3] > $vstandard) {	# peak of carrier found
							push @vcarrier, $data[$fs - 1];
							push @vfreq, $vfrequency - $data[4];
# 	print $data[$fs - 2] . "   " . $data[$fs - 1] . "   " . $data[$fs] . "\n";
						}
						$vslope = -1;
					}
					if ($data[$fs] > $data[$fs - 1] && $vslope == -1) {		# inversion rising
						$vslope = 1;
					}
					$vfrequency += $data[4];
				}
				my $carriercount = @vcarrier;
				$DLevel > 1 && print "Found $carriercount carrier\n";
				for(my $fc = 0; $fc < $carriercount; $fc ++) {
					print $vfreq[$fc] / 1e6 . " MHz  " . $vcarrier[$fc] . " dB\n";
				}
				undef(@vfreq);
				undef(@vcarrier);
			}
		}
		close(FILE);
		$DLevel > 0 && print"\nAnalyzed $lcount lines with " . ($values - 6) . " values from '$ReadFile'.\n";
	} else {
		return -1;
	}
	return $lcount;
}


###############################################################################
# Show scan areas
###############################################################################

sub ScanList {
	print "Found $ScanCount scan areas:\n\n";
	
	for(my $sa = 0; $sa < $ScanCount; $sa ++) {
		print "Area ";
		print $sa + 1;
		if ($Scan[$sa]->{'active'}) {
			print " ON :";
		} else {
			print " Off:";
		}
		print " from " . $Scan[$sa]->{'freq_from'};
		print " to "   . $Scan[$sa]->{'freq_to'};
		if (exists $Scan[$sa]->{'freq_offset'}) {
			print " (" . $Scan[$sa]->{'freq_offset'} . ")";
		}
		print " step " . $Scan[$sa]->{'freq_step'};
		print " in "   . $Scan[$sa]->{'seconds'} . " seconds\n";
		
		if (! -d $Scan[$sa]->{'path_daily'}) {			# Create directory if it does not exist
			mkdir $Scan[$sa]->{'path_daily'} or die "ERROR creating directory '" . $Scan[$sa]->{'path_daily'} . "': $!\n";
			$DLevel > 0 && print "Directory " . $Scan[$sa]->{'path_daily'} . " created.\n";
		}
	}
}


###############################################################################
# format actual timestamp
# e = european format TT.MM.YYYY HH:MM:SS
# i = inverse  format YYYY.MM.TT-HH.MM.SS
###############################################################################

sub DateTime {
	my $format = $_[0];
	my $Xdatum;
	my $Xzeit;
	my $Xreturn;

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$ydat,$isdst) = localtime();
	my $jahr = $year;
	my $monat = $mon + 1;
	my $tag = $mday;

	$jahr = $year + 1900;

	if (length($monat) == 1) { $monat="0$monat"; }
	if (length($tag) == 1) { $tag="0$tag"; }
	if (length($hour) == 1) { $hour="0$hour"; }
	if (length($min) == 1) { $min="0$min"; }
	if (length($sec) == 1) { $sec="0$sec"; }

	if ($format eq "i") {
		$Xdatum = $jahr . "." . $monat . "." . $tag;
		$Xzeit = $hour . "." . $min . "." . $sec;
		$Xreturn = $Xdatum . "-" . $Xzeit;
	} else {
		$Xdatum = $tag . "." . $monat . "." . $jahr;
		$Xzeit = $hour . ":" . $min . ":" . $sec;
		$Xreturn = $Xdatum . " " . $Xzeit;
	}

	return $Xreturn;
}


##################################################################################
# round float
##################################################################################

sub round {
	my $value  = $_[0];
	my $digit  = $_[1];
	
	my $rwert = abs($value);
	
	$digit = int($digit);
	if ($digit < 0) { $digit = 0; }
	$rwert = (int($rwert * (10 ** $digit) + 0.5555555555555555 ) / (10 ** $digit));
	if ($value < 0) { $rwert = $rwert * -1; }
	
	return $rwert;
}


###############################################################################
# Logfile and console print
###############################################################################

sub LogPrint {
	my $message = $_[0];

	$DLevel > 0 && print "$message\n";
	if ($opt_log) {
		print LOut "\<" . DateTime("e") . "\> $message\n";
	}
}


###############################################################################
# Exec shell command
###############################################################################

sub SysExec{
	my $RExec = $_[0];
	my $result;

	$DLevel > 2 && print "SHELL: '$RExec'\n";
	if ($opt_sim) {
		$result = 0;
	} else {
		$result = (system ($RExec))/256;
	}
	if ($result != 0) {
		LogPrint ("\nERROR executing a shell command!\n" . 
		"Command  : $RExec\n" . 
		"Exitcode : $result");

# 		close(LOut);
# 		exit 1;
	}
	return $result;
}
