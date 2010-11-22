#!/usr/bin/perl -w

use strict;

#
# Expected input: (stdin) is lines of the form
#
# cursym nextsym probsym [extra]
#
# Where the fields are tab-delimintated (allowing for spaces
# to occur in the symbols
#
#


my ($cursym,$predsym,$lastpredsym,$n,$n_predsym,$n_predsymcorrect,$n_lastpredsym);

$n=0;
$n_predsym=0;
$n_predsymcorrect=0;
$n_lastpredsym=-1;

my $line;

while ($line=<STDIN>) { 
  chomp $line;
  my @data=split(/\t/,$line);
  $cursym=$data[0];
  $predsym=$data[1];
#  print $cursym," *** ", $predsym, "\n";
  $n++;
  if (! ($predsym eq "can't predict")) { 
    if ($n>1) { 
      if ($n_lastpredsym == ($n-1)) {
	if ($lastpredsym eq $cursym) { 
	  $n_predsymcorrect++;
	}
      }
    }
    $lastpredsym=$predsym;
    $n_predsym++;
    $n_lastpredsym=$n;
  }
}

print "Summary\n";
print "-------\n\n";

print "Number of symbols:                 $n\n";
print "Number of prediction attempts:     $n_predsym (".
  (100.0*$n_predsym/$n)." % of total)\n";
print "Number of correct attempts:        $n_predsymcorrect (".
  ($n_predsym > 0 ? (100.0*$n_predsymcorrect/$n_predsym) : 0)." % of attempts, ".
  (100.0*$n_predsymcorrect/$n)." % of total)\n";
print "\n";

