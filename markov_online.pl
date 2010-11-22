#!/usr/bin/perl -w
use strict;
use markov;
use Getopt::Long;
use Data::Dumper;

my $timestamp=0;
my $ub= -1;
my $lb= -1;
my $numahead=1;

&GetOptions(("timestamp"=>\$timestamp, 
	     "statelb=i"=>\$lb, 
	     "stateub=i"=>\$ub, 
	     "numahead=i"=>\$numahead));

$#ARGV==0 or die "usage: markov_online.pl [--timestamp] [--statelb=lb --stateub=ub] [--numahead=na] order < file\n";

my $order=shift;

my $model=MakeModel($order);

while (my $sym=<STDIN>) { 
  chomp($sym);
  if ($timestamp) { 
    $sym=~/^\S+\s+(.*)$/;
    $sym=$1;
  }
  StepSymbol($model,$sym);
  if ($numahead==1) {
    my ($nextsym,$probsym, $nextstate,$probstate)=NextSymbolAndState($model);
    if (defined($nextsym)) { 
      print join("\t",$sym,$nextsym,$probsym, $nextstate,$probstate),"\n";
    } else {
      print "$sym\tcan't predict\n";
    }
  } else {
    my $pred=NextKSymbolsAndStates($model,$numahead);
    print $sym;
    for (my $i=0;$i<$numahead;$i++) { 
#      print Dumper($pred);
      if (!defined($pred->{symbollist}) || !defined($pred->{symbollist}->[$i])) { 
	print "\tcan't predict";
	last;
      }
      print "\t", join("\t",$pred->{symbollist}->[$i],
		       $pred->{symbolprob}->[$i],
		       $pred->{statelist}->[$i],
		       $pred->{stateprob}->[$i]);
    }
    print "\n";
  }
      
  if ($lb>0) { 
    ElliminateInfrequentStatesAndTheirTransitions($model,$ub,$ub,$lb);
  }
#  print STDERR "Top: ".Dumper($model);
}



