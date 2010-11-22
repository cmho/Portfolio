#!/usr/bin/perl -w

use Getopt::Long;

$#ARGV>=2 or die "usage: time_series_symbol.pl symbol steps-ahead model \n";

$symbol=shift;
$steps=shift;
$model=join(" ",@ARGV);

$cmd = "get_data.pl --nodate --close $symbol | (time_series_predictor_online $steps $model 2>/dev/null) | time_series_evaluator_online $steps";

system  $cmd;
