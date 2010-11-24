#!/usr/bin/perl -w

use Data::Dumper;
use Finance::Quote;
#use strict;

#$#ARGV>=0 or die "usage: quote.pl  SYMBOL+\n";

my @info=("date","time","high","low","close","open","volume");

open(SYMBOLS, "symbols.txt");

my @symbols = SYMBOLS;

my $con=Finance::Quote->new();

$con->timeout(60);

my %quotes = $con->fetch("usa",@symbols);

while(*SYMBOLS){
	my ($line) = $_;
	chomp($line);
	print my $symbol,"\n=========\n";
    if (!defined($quotes{$symbol,"success"})) { 
	print "No Data\n";
    } else {
	foreach my $key (@info) {
	    if (defined($quotes{$symbol,$key})) {
		print $key,"\t",$quotes{$symbol,$key},"\n";
	    }
	}
    }
    print "\n";
}
close(SYMBOLS);