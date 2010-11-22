#!/usr/bin/perl -w

use Getopt::Long;

$#ARGV==1 or die "usage: genetic_symbol.pl symbol window \n";

($symbol, $window)=@ARGV;

system "get_data.pl --nodate --close $symbol > data.gp.in;  genetic_predictor_offline data.gp.in $window >/dev/null 2>&1 ";

print "Best of each generation:\n";

system "cat data.dat";

print "\nDone.  See complete results in data.*\n";

