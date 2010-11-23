#!/usr/bin/perl

use DBI;
use strict;

my $user = "cs339";
my $password = "cs339";
my $host = "localhost";

my $dbh = DBI->connect("dbi:mysql:database=cs339;host=$host", $user, $password)
	or die $DBI::errstr;

my $query = $dbh->prepare("select symbol from StocksDaily")
	or die $DBI::errstr;
	
$query->execute();

open(SYMBOLS, '>>symbols.txt');

my @symbol;
while (@symbol = $query->fetchrow_array) {
	print SYMBOLS "@symbol ";
}

$dbh->disconnect or die $DBI::errstr;