#!/usr/bin/perl -w

$#ARGV==0 or die "usage: stepify.pl numsteps < input > output\n";

@data=<STDIN>;

$levels=shift;

@steps=0..$levels;

$max=0;
map { $max = $_  if $_ > $max; } @data;
map { print $steps[ $levels * $_ / $max ], "\n"; } @data;


