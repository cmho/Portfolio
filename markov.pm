package markov;

require Exporter;

@ISA=qw(Exporter);
@EXPORT= qw(MakeModel 
	    StepSymbol
	    GetModelSize
	    ElliminateInfrequentStatesAndTheirTransitions
	    NextStateDistribution
	    NextSymbolDistribution
	    NextSymbolAndState
	    SwitchToRandomState
	    SimulateModel
	    PrintModel
	    AddSymbol
            AddStateTransitionFromSymbols
            AddStateTransition
            NextSymbolFromSymbols 
            NextSymbolFromState
	    NextStateDistributionFromInputDistribution
	    KthStateDistributionFromCurrentState
	    KthSymbolDistributionFromCurrentState
	    KthSymbolAndState
	    NextKSymbolsAndStates
);

use strict;
use Data::Dumper;


my $ALL_SYMBOL="all999xxx";

#
#
#
# A model is a hash containing
#
# $order       - order
# $numsyms     - number of symbols seen
# $numstates   - number of states seen
# $curstate    - current state
# \%symbols - list of the symbols found in the stream and their occarances
# \%statel  - list of states given the symbolstream and their occurances
#
# \%counthash  - $counthash{$state1}{$ALL_SYMBOL} = total count going out of state
#                $counthash{$state1}{$state2} = count going from state1 to state2
#
# \%counthashrev - reversed counthash, so that we can find all incoming edges
#                  to a state

sub MakeModel {
  my ($order, $symbolstream) = @_;
  my %model;

  $model{order}=$order;

  if (defined($symbolstream)) { 
    map {StepSymbol(\%model,$_)} @{$symbolstream};
  }
  return \%model;
}

sub SwitchToRandomState {
  my ($model)=@_;
  my @states = keys %{$model->{states}};
  $model->{curstate}=$states[rand($#states + 1)];
}

##################################################################################
# Added Functionality by Blair Heuer to support direct addition of 
# state transitions
#

sub AddSymbol {
  my $model = shift;
  my $symbol = shift;
  
  # handle new symbol
  $model->{numsyms}++;
  $model->{symbols}->{$symbol}++; 
  
  return $model->{numsyms};
}

sub AddStateTransitionFromSymbols {
  my $model = shift;
  my @symbols = @_;

  # create the states
  my $laststate = "_" . join("_",@symbols[0..($#symbols - 1)]);
  my $curstate = "_" . join("_",@symbols[1..$#symbols]);
  
  AddStateTransition($model, $laststate, $curstate);
}
  
sub AddStateTransition {
  my $model = shift;
  my $laststate = shift;
  my $curstate = shift;

  # handle states
  $model->{states}->{$curstate}++;
  $model->{numstates}++;
  $model->{counthash}->{$laststate}{$ALL_SYMBOL}++;
  $model->{counthash}->{$laststate}{$curstate}++;
  $model->{counthashrev}->{$curstate}{$laststate}++;

}

sub NextSymbolFromSymbols {
  my $model = shift;
  my @symbols = @_;
  
  # create state
  my $curstate = "_" . join("_",@symbols);
  
  NextSymbolFromState($model, $curstate);
}

sub NextSymbolFromState {
  my $model = shift;
  my $curstate = shift;
  
  # set state as current
  $model->{curstate}=$curstate;
  
  # get prediction
  my ($nextsym,$probsym, $nextstate,$probstate)=NextSymbolAndState($model);
  
  return $nextsym;
  
}

#######################################################################################


sub StepSymbol {
  my ($model, $symbol) = @_;
  my $curstate;
  my $laststate;

  if (!defined($model->{curstate})) { 
    $curstate="_".$symbol;
  } else {
    $laststate=$model->{curstate};
    my @syms=split(/\_/, $laststate); 
    shift @syms;
    if (($#syms+1)<$model->{order}) { 
      $curstate=$laststate."_".$symbol;
    } elsif (($#syms+1)>$model->{order}) { 
      print "ERROR:  state string $laststate is inexplicably too dimensional - probably have '_'s in the input\n";
      exit(-1);
    } else {
      $curstate=join("_", "",@syms[1..$#syms],$symbol);
    }
  }
  $model->{curstate}=$curstate;
  $model->{numsyms}++;
  $model->{symbols}->{$symbol}++;
  if ($model->{numsyms}<$model->{order}) { 
    # do nothing
  } elsif ($model->{numsyms}==$model->{order}) { 
    $model->{states}->{$curstate}++;  
    $model->{numstates}++;
  } else {
    $model->{states}->{$curstate}++;
    $model->{numstates}++;
    $model->{counthash}->{$laststate}{$ALL_SYMBOL}++;
    $model->{counthash}->{$laststate}{$curstate}++;
    $model->{counthashrev}->{$curstate}{$laststate}++;
  }
#  print Dumper($model);
}

#
# ellinate all but the top $n states and their related transitions
#
# if $ub $lb are provided, then function will only do work 
# if there are more than $ub states and shrink down to $lb states
#
sub ElliminateInfrequentStatesAndTheirTransitions {
  my ($model, $n, $ub, $lb) = @_;
  

  if (!defined($ub)) { 
    $ub=$lb=$n;
  }

  my $numstates = scalar keys %{$model->{states}};
 
  if ($numstates <= $ub) { 
#    print STDERR "Skipping Shrink\n";
    return;
  }


  #
  # Get the states of the model in rank order
  # 
  #
  my @states=sort { $model->{states}->{$b} <=> $model->{states}->{$a} } keys %{$model->{states}};
  
  #
  # We must assure that the current state is not discarded or else
  # we will have a memory leak
  #
  # We'll remove it from the list and insert it into the front;
  my $cs;
  for ($cs=0;$cs<=$#states;$cs++) { 
    last if $states[$cs] eq $model->{curstate};
  }
  @states = ($states[$cs],@states[0..$cs-1],@states[$cs+1..$#states]);
  

#  print STDERR "$lb $ub $numstates $#states\n";
#  print STDERR (map { " ($_,$model->{states}->{$_}) " } @states[0..10]), "\n";
#  print STDERR (map { " ($_,$model->{states}->{$_}) " } @states[$lb..($lb+10)]), "\n";

#  print STDERR "Begin!\n";
#  print STDERR Dumper($model),"\n";

  foreach my $skill (@states[$lb..$#states]) { 
#    print STDERR "Killing $skill\n";
    #
    # Kill all outgoing edges from state
    #
#    print STDERR "Deleting ($skill -> *)\n";
    delete $model->{counthash}->{$skill};
#    print STDERR Dumper($model),"\n";
    #
    # Kill all incoming edges to state
    #
    foreach my $s ( keys %{$model->{counthashrev}->{$skill}} ) { 
#      print STDERR "Deleting ($s -> $skill)\n";
      if (defined($model->{counthash}->{$s}{$skill})) { 
	$model->{counthash}->{$s}{$ALL_SYMBOL} -= $model->{counthash}->{$s}{$skill};
	delete $model->{counthash}->{$s}{$skill};
	if (scalar(keys %{$model->{counthash}->{$s}})==1) { 
	  delete $model->{counthash}->{$s};
	}
      }
#      print STDERR Dumper($model),"\n";
    }
    #
    # kill reverse hash entries
    #
#    print STDERR "Deleting all bookkeeping data on $skill edges\n";
    delete $model->{counthashrev}->{$skill};
#    print STDERR Dumper($model),"\n";

    #
    # Kill the state
    #
#    print STDERR "Deleting $skill\n";
    delete $model->{states}->{$skill};
#    print STDERR Dumper($model),"\n";
  }

  #
  # Now, of the keepers, kill bad incoming edges from reverse entries
  # that no longer exist
  #
  foreach my $s (keys %{$model->{states}}) { 
    foreach my $skill (keys %{$model->{counthashrev}->{$s}} ) {
      if (!defined($model->{states}->{$skill})) { 
	delete $model->{counthashrev}->{$s}{$skill};
      }
    }
  }

  my $newnumstates = scalar keys %{$model->{states}};

#  print STDERR "Shrank from $numstates states to $newnumstates states\n";
#  print STDERR join("\t",GetModelSize($model)),"\n";
  
#  print STDERR Dumper($model),"\n";

}

sub GetModelSize {
  my $model=shift;
  my $numsymbols;
  my $numstates;
  my $numcounthash;
  my $numcounthashrev;
  my $s;
  
  $numsymbols=scalar(keys %{$model->{symbols}});
  $numstates=scalar(keys %{$model->{states}});
  $numcounthash=0;
  foreach $s (keys %{$model->{counthash}}) { 
    $numcounthash+=scalar(keys %{$model->{counthash}->{$s}});
  }
  $numcounthashrev=0;
  foreach $s (keys %{$model->{counthashrev}}) { 
    $numcounthashrev+=scalar(keys %{$model->{counthashrev}->{$s}});
  }

  return ($numsymbols+$numstates+$numcounthash+$numcounthashrev,$numsymbols,$numstates,$numcounthash,$numcounthashrev);
}

sub SimulateModel {
  my ($model)=@_;
  my $syms=NextSymbolDistribution($model);
  if (!defined($syms)) { 
    print "Undefined syms in SimulateModel\n";
    exit(-1);
  }
  my @symsorted= sort { $syms->{$b} <=> $syms->{$a} } keys %{$syms};
  my $r=rand;
  my $p=0;
  my $sym;
  my $foundsym;
  foreach $sym (@symsorted) {
    $p+=$syms->{$sym};
#    print "$sym $p $r\n";
    if ($p>=$r) {
      $foundsym=$sym;
      last;
    }
  }
  if (defined($foundsym)) { 
    StepSymbol($model,$foundsym);
    return $foundsym;
  } else {
    SwitchToRandomState($model);
    return SimulateModel($model);
  }
}

sub NextStateDistributionFromInputDistribution {
  my ($model, $curdistref) = @_;
  my %nextdist;
  my ($left, $right);
  
  #
  #
  # For every nonzero probable state in the current distribution
  # (the "left hand" state)
  #
  foreach $left (keys %{$curdistref}) {
    next if ($left eq $ALL_SYMBOL);
    #
    #
    # Consider all of its target states (the "right hand" state)
    #
    foreach $right (keys %{$model->{counthash}->{$left}} ) {
      next if ($right eq $ALL_SYMBOL);
      #print "left=$left, right=$right, $curdistref->{$left}
      $nextdist{$right} += 
	# probability of being in the left hand state in the 
	# current distribution times
	$curdistref->{$left} *           
	# probability of transitioning to the right hand state
	# which is count of transition divided by total outgoing count
	( $model->{counthash}->{$left}{$right} / 
           $model->{counthash}->{$left}{$ALL_SYMBOL} );
    }
  }
  return \%nextdist;
}

sub KthStateDistributionFromCurrentState {
  my ($model,$k)=@_;
  my $nextdistref = { $model->{curstate} => 1.0 };
  while ($k>0) { 
    $nextdistref = NextStateDistributionFromInputDistribution($model,$nextdistref);
    $k--;
  }
  return $nextdistref;
}

sub KthSymbolDistributionFromCurrentState {
  my ($model, $k) =@_;
  my %next;

  my $next = KthStateDistributionFromCurrentState($model,$k);
  my %syms;
  map { my @junk=split(/\_/,$_); $syms{$junk[$#junk]}+=$next->{$_}; } keys %{$next};
  return \%syms;
}


sub KthSymbolAndState {
  my ($model,$k)=@_;

  if (!defined($model->{numstates}) || $model->{numstates}<1) {
    return undef;
  }

  my $next = KthStateDistributionFromCurrentState($model,$k);
  my $max=0;
  my $maxkey='';
  foreach my $key (keys %{$next}) { 
    if ($next->{$key} > $max) { 
      $max=$next->{$key};
      $maxkey=$key;
    }
  }
  my $syms = KthSymbolDistributionFromCurrentState($model,$k);
  my @symsorted= sort { $syms->{$b} <=> $syms->{$a} } keys %{$syms};
  
  if (defined($symsorted[0])) { 
    return ($symsorted[0], $syms->{$symsorted[0]}, $maxkey,$max);
  } else {
    return undef;
  }
}

#
# Returns
# a reference to a hash containing
# $ret{statelist} = reference to list of states
# $ret{stateprob} = corresponding probabilities
# $ret{symbollist} = reference to list of symbols
# $ret{symbolprob} = corresponding probabilities
sub NextKSymbolsAndStates {
  my ($model,$k)=@_;
  my $nextdistref = { $model->{curstate} => 1.0 };
  my %ret;
  while ($k>0) { 
    $nextdistref = NextStateDistributionFromInputDistribution($model,$nextdistref);
    $k--;
    next if (scalar(keys %{$nextdistref})==0);

    # find most likely state
    my $max=0;
    my $maxkey='';
    foreach my $key (keys %{$nextdistref}) { 
      if ($nextdistref->{$key} > $max) { 
	$max=$nextdistref->{$key};
	$maxkey=$key;
      }
    }
    push @{$ret{statelist}}, $maxkey;
    push @{$ret{stateprob}}, $max;
    # 
    # Now find most likely symbol
    # note that this is complicated because multiple states may end
    # with the same symbol
    my %syms;
    map { my @junk=split(/\_/,$_); $syms{$junk[$#junk]}+=$nextdistref->{$_}; } keys %{$nextdistref};
    $max=0;
    $maxkey='';
    foreach my $key (keys %{syms}) { 
      if ($syms{$key} > $max) { 
	$max=$syms{$key};
	$maxkey=$key;
      }
    }
    push @{$ret{symbollist}}, $maxkey;
    push @{$ret{symbolprob}}, $max;
  }
  return \%ret;
}

  


sub NextStateDistribution {
  my ($model) =@_;
  my %next;

#  print Dumper($model);

  if ($model->{numstates}<1) { 
    return undef;
  } 
  map { 
    if (!($_ eq $ALL_SYMBOL)) { 
      $next{$_}=$model->{counthash}->{$model->{curstate}}{$_} / $model->{counthash}->{$model->{curstate}}{$ALL_SYMBOL}; 
    } 
  } keys %{$model->{counthash}->{$model->{curstate}}} ;
  
  return \%next;
}

sub NextSymbolDistribution {
  my ($model) =@_;
  my %next;

  my $next = NextStateDistribution($model);
  my %syms;
  map { my @junk=split(/\_/,$_); $syms{$junk[$#junk]}+=$next->{$_}; } keys %{$next};
  return \%syms;
}

sub NextSymbolAndState {
  my ($model)=@_;

  if (!defined($model->{numstates}) || $model->{numstates}<1) {
    return undef;
  }

  my $next = NextStateDistribution($model);
  my $max=0;
  my $maxkey='';
  foreach my $key (keys %{$next}) { 
    if ($next->{$key} > $max) { 
      $max=$next->{$key};
      $maxkey=$key;
    }
  }
  my $syms = NextSymbolDistribution($model);
  my @symsorted= sort { $syms->{$b} <=> $syms->{$a} } keys %{$syms};
  
  if (defined($symsorted[0])) { 
    return ($symsorted[0], $syms->{$symsorted[0]}, $maxkey,$max);
  } else {
    return undef;
  }
}


sub PrintNextInfo {
  my ($model)=@_;
  my $nextstate=NextStateDistribution($model);
  my $nextsym=NextSymbolDistribution($model);
  my ($sym, $state, $prob) = NextSymbolAndState($model);
  my %syms;

  print "Next Symbol:      \t",$sym, "\n";
  print "Next State:       \t",$state, "\n";
  print "Probability:      \t",$prob, "\n";
  print "\n";

  print "Next Symbol Distribution\n";
  print map { "\t $_ = ".$nextsym->{$_}."\n"} sort { $nextsym->{$b} <=> $nextsym->{$a} } keys %{$nextsym};
  print "\n";
  print "Next State Distribution\n";
  print map {"\t $_ = ".$nextstate->{$_}."\n"} sort { $nextstate->{$b} <=> $nextstate->{$a} } keys %{$nextstate};

  print "\n";
 
}

sub PrintModel {
  my ($modelref)=@_;

#  print Dumper($modelref);
  
  print "Markov model\n";
  print "=========================================================================\n";
  print "Order of model:    \t",$modelref->{order},"\n";
  print "Number of symbols: \t",scalar(keys %{$modelref->{symbols}}),"\n";
  print "Number or states:  \t",scalar(keys %{$modelref->{states}}),"\n\n";
  print "Current state:     \t",$modelref->{curstate},"\n";
  print "\n";
  print "Observed symbols:  \t",$modelref->{numsyms},"\n";
  print map {"\t$_\n"} sort keys %{$modelref->{symbols}};
  print "\n";
  print "Observed states:   \t",$modelref->{numstates},"\n";
  print map {"\t$_\n"} sort keys %{$modelref->{states}};
  print "\n";
  PrintNextInfo($modelref);
  print "Transition Matrix\n\n";
  
  print map {"\t$_"} sort keys %{$modelref->{states}};
  print "\n";
  foreach my $s1 (sort keys %{$modelref->{states}}) {
    print "$s1";
    foreach my $s2 (sort keys %{$modelref->{states}}) {
#      print Dumper($modelref->{counthash});
      if (defined($modelref->{counthash}->{$s1}{$s2})) { 
	print "\t", $modelref->{counthash}->{$s1}{$s2} / $modelref->{counthash}->{$s1}{$ALL_SYMBOL};
      } else {
	print "\t0.0";
      }
    }
    print "\n";
  }
  print "=========================================================================\n";
}


