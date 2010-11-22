#!/usr/bin/perl -w

use Data::Dumper;
use Finance::Quote;

$#ARGV>=0 or die "usage: quote.pl  SYMBOL+\n";


@info=("date","time","high","low","close","open","volume");


@symbols=@ARGV;

$con=Finance::Quote->new();

$con->timeout(60);

%quotes = $con->fetch("usa",@symbols);

foreach $symbol (@ARGV) {
    print $symbol,"\n=========\n";
    if (!defined($quotes{$symbol,"success"})) { 
	print "No Data\n";
    } else {

	foreach $key (@info) {
	    if (defined($quotes{$symbol,$key})) {
		print $key,"\t",$quotes{$symbol,$key},"\n";
	    }
	}
    }
    print "\n";
}


