#!/usr/bin/perl -wT

#
# Some debugging options
# all of this debugging info will be shown at the *end* of script
# execution.
#
# database input and output is paired into the two arrays noted
#
my $show_params    = 1;
my $show_cookies   = 1;
my $show_sqlinput  = 1;
my $show_sqloutput = 1;
my @sqlinput       = ();
my @sqloutput      = ();

#
# The combination of -w and use strict enforces various
# rules that make the script more resilient and easier to run
# as a CGI script.
#
use lib '/home/cmh736/public_html/portfolio';
#use strict;

# The CGI web generation stuff
# This helps make it easy to generate active HTML content
# from Perl
#
# We'll use the "standard" procedural interface to CGI
# instead of the OO default interface
use CGI qw(:standard);
use CGI;
use CGI::Carp qw (fatalsToBrowser);
use File::Basename;
use HTML::Template;
use Data::Serializer;

$CGI::POST_MAX = 1024 * 5000;

# The interface to the database.  The interface is essentially
# the same no matter what the backend database is.
#
# DBI is the standard database interface for Perl. Other
# examples of such programatic interfaces are ODBC (C/C++) and JDBC (Java).
#
#
# This will also load DBD::Oracle which is the driver for
# Oracle.
use DBI;

#
#
# A module that makes it easy to parse relatively freeform
# date strings into the unix epoch time (seconds since 1970)
#
use Time::ParseDate;

#
# The following is necessary so that DBD::Oracle can
# find its butt
#
$ENV{ORACLE_HOME}="/opt/oracle/product/11.2.0/db_1";
$ENV{ORACLE_BASE}="/opt/oracle/product/11.2.0/db_1";
$ENV{ORACLE_SID}  = "CS339";

#
# You need to override these for access to your database
#
my $dbuser   = "crb910";
my $dbpasswd = "o10d5691d";

#
# The session cookie will contain the user's name and password so that
# he doesn't have to type it again and again.
#
# "MicroblogSession"=>"user/password"
#
# BOTH ARE UNENCRYPTED AND THE SCRIPT IS ALLOWED TO BE RUN OVER HTTP
# THIS IS FOR ILLUSTRATION PURPOSES.  IN REALITY YOU WOULD ENCRYPT THE COOKIE
# AND CONSIDER SUPPORTING ONLY HTTPS
#
my $cookiename = "PortfolioSession";

#
# Get the session input cookie, if any
#
my $inputcookiecontent = cookie($cookiename);

#
# Will be filled in as we process the cookies and paramters
#
my $outputcookiecontent = undef;
my $deletecookie        = 0;
my $user                = undef;
my $password            = undef;
my $loginok             = 0;
my $logincomplain       = 0;

#
#
# Get action user wants to perform
#
my $template = HTML::Template->new(filename => '/home/cmh736/public_html/portfolio/portfolio.tmpl',
    								die_on_bad_params => 0);
my $action;
if ( param("act") ) {
    $action = param("act");
    $template->param(LOGINSCREEN => 0);
}
else {
    $action = "login";
    $template->param(LOGINSCREEN => 1);
}

#
# Is this a login request or attempt?
# Ignore cookies in this case.
#
if ( $action eq "login" || param('loginrun') || $action eq "register" ) {
    if ( param('loginrun') ) {

        #
        # Login attempt
        #
        # Ignore any input cookie.  Just validate user and
        # generate the right output cookie, if any.
        #
        ( $user, $password ) = ( param('user'), param('password') );
        if ( ValidUser( $user, $password ) ) {

            # if the user's info is OK, then give him a cookie
            # that contains his username and password
            # the cookie will expire in one hour, forcing him to log in again
            # after one hour of inactivity.
            # Also, land him in the query screen
            $outputcookiecontent = join( "/", $user, $password );
            $loginok = 1;
            $template->param(LOGINSCREEN => 0);
            $template->param(OVERVIEW => 1);
        }
        else {

            # uh oh.  Bogus login attempt.  Make him try again.
            # don't give him a cookie
            $logincomplain = 1;
            $action        = "login";
            $template->param(LOGINSCREEN => 1);
        }
    }
    elsif ( $action eq "register" ) {
    		$template->param(LOGINSCREEN => 0);
			$template->param(REGISTERSCREEN => 1);
			$template->param(TITLE => "Register");
			if (param('adduserrun')) { 
				my $firstname=param('firstname');
		    	my $lastname=param('lastname');
		    	my $email=param('email');
		    	my $username=param('username');
		    	my $password=param('password');
		    	my $error;
		    	$error=UserAdd($firstname,$lastname,$username,$password,$email);
		    	if ($error) { 
					$template->param(REGFAILED => 1);
		      	} else {
					$template->param(JUSTLOGGEDIN => 1);
					$template->param(LOGINSCREEN => 0);
					$template->param(REGISTERSCREEN => 0);
		      	}
			}

        #
        # Just a login screen request. Still, ignore any cookie that's there.
        #
    }
}
else {

    #
    # Not a login request or attempt.  Only let this past if
    # there is a cookie, and the cookie has the right user/password
    #
    if ($inputcookiecontent) {

        # if the input cookie exists, then grab it and sanity check it
        ( $user, $password ) = split( /\//, $inputcookiecontent );
        if ( !ValidUser( $user, $password ) ) {

            # Bogus cookie.  Make him log in again.
            $action = "login";

            # don't give him an output cookie
        }
        else {

            # cookie is OK, give him back the refreshed cookie
            $outputcookiecontent = $inputcookiecontent;
			$template->param(LOGINSCREEN => 0);
        }
    }
    else {

        #
        # He has no cookie and must log in.
        #
        $action = "login";
        #$template->param(LOGINSCREEN => 1);
    }
}

#
# If we are being asked to log out, then if
# we have a cookie, we should delete it.
#
if ( $action eq "logout" ) {
    $deletecookie = 1;
}

#
# OK, so now we have user/password
# and we *may* have a cookie.   If we have a cookie, we'll send it right
# back to the user.
#
# We force the expiration date on the generated page to be immediate so
# that the browsers won't cache it.
#
if ($outputcookiecontent) {
    my $cookie = cookie(
        -name    => $cookiename,
        -value   => $outputcookiecontent,
        -expires => ( $deletecookie ? '-1h' : '+1h' )
    );
    print header( -expires => 'now', -cookie => $cookie );
}
else {
    print header( -expires => 'now' );
}

#
# Now we finally begin spitting back HTML
#

if ($loginok) {
    $template->param(LOGINSCREEN => 0);
    $template->param(JUSTLOGGEDIN => 1);
}

#
#
# The remainder here is essentially a giant switch statement based
# on $action.  In response to an action, we will put up one or more forms.
# Each form contains a hidden parameter that lets us know whether the
# script is being called with form contents. If we are getting form contents
# we also generate the output following it
#
#

# LOGIN
#
# Login is a special case since we handle the filled out form up above
# in the cookie-handling code.  So, here we only put up the form.
#
#

if ( $action eq "login" ) {
    if ($logincomplain) {
        $template->param(LOGINFAILED => 1);
       	$template->param(LOGINSCREEN => 1);
    }
} elsif ( $action eq "logout" ) {
    $template->param(LOGOUTSUCCESS => 1);
    $template->param(LOGINSCREEN => 1);
    $action = "login";
} elsif ( $action eq "overview" ) {
	$template->param(LOGINSCREEN => 0);
	$template->param(JUSTLOGGEDIN => 1);
	$template->param(NAME => $user);
    $template->param(TITLE => "Overview");
} elsif ( $action eq "portfolioadd" ) {
	$template->param(LOGINSCREEN => 0);
	$template->param(PORTFOLIO_ADD => 1);
	$template->param(TITLE => "Add New Portfolio");
	my @res;
	if (param("createrun")) {
		my $name = param("name");
		my $acct = param("cash");
		eval {
			@res = ExecSQL($dbuser, $dbpasswd, "insert into stock_holdings(name, cashacct) values(" . $name . ", " . $cash . ")");
		};
	}
} elsif ( $action eq "portfoliolist" ) {
    $template->param(LOGINSCREEN => 0);
    $template->param(PORTFOLIOS => 1);
    $template->param(TITLE => "Your Portfolios");
    my @res;
    if (param("folio")) {
    	eval {
    		@res = ExecSQL($dbuser, $dbpasswd, "select * from stock_holdings where name=?", param("folio"));
    	};
    } else {
    	eval {
    		@res = ExecSQL($dbuser, $dbpasswd, "select name from stock_holdings where username = '?' order by name", $user);
    	};
    	my $out = "";
    	foreach my $result (@res) {
			my ( $name ) = @${$result};
			$out .= "\t<dt>" . $name . "</dt>\n\t<dd>0</dd>";
    		$template->param(PORTFOLIO_LISTING => $out);
    	}
    }
} elsif ( $action eq "browse" ) {
	$template->param(LOGINSCREEN => 0);
	$template->param(TITLE => "Browse Stocks");
	$template->param(BROWSE => 1);
	my @res;
	my $out = "";
	if (param("stock")) {
		$template->param(STOCK => param("stock"));
		eval {
			@res = ExecSQL($dbuser, $dbpasswd, "select * from symbols where shortname=?", param("stock"));
		};
		my @values = ();
		foreach my $result (@res) {
			my ( $id, $stockname, $stockshort, $stockcur, $stockold ) = @${$result};
			$template->param(STOCKNAME => $stockname);
			$template->param(STOCK_SHORT => $stockshort);
			$template->param(STOCK_CURRENT => $stockcur);
			@values = deserialize($stockold);
		}
		
	} else {
		$out .= "<dl>\n\t";
		eval {
			@res = ExecSQL($dbuser, $dbpasswd, "select shortname, longname, val from symbols order by shortname");
		};
		foreach my $result (@res) {
			my ( $shortname, $longname, $val ) = @${$result};
			$out .= "\t<dt><a href=\"index.pl?act=browse&stock=" . $shortname . "\">" . $longname . "(" . $shortname . ")</a></dt>\n";
			$out .= "\t<dd>" . $val . "</dd>\n";
		}
		$out .= "</dl>";
	}
	$template->param(BROWSE_OUT => $out);
} elsif ( $action eq "cash" ) {
	$template->param(LOGINSCREEN => 0);
	if ( param("id" )) {
		$template->param(TITLE => "Cash Account: " . $id . "");
		$template->param(CASH => 1);
		$template->param(CASH_VIEW => 1);
		if (param('withdrawcashrun')) { 
			my $withdraw = ('withdrawamt');
			my $accname = ('accountname');
			my $ttype   = ('WITH');
    		$error = DepositCash($accname,$ttype,$withdraw);
    		if ($error) { 
				$template->param(WITHDRAWNOTOK => 1);
    		} else {
				$template->param(WITHDRAWOK => 1);
    		}
		
		}
		if (param('depositcashrun')) { 
			my $deposit = ('depositamt');
			my $accname = ('accountname');
			my $ttype   = ('DEPO');
		    $error=DepositCash($accname,$ttype,$deposit);
		    if ($error) { 
				$template->param(DEPOSITNOTOK => 1);
		    } else {
				$template->param(DEPOSITOK => 1);
		    }
		}
		my $id = param("id");
		my @acctinfo;
		eval {
			@acctinfo = ExecSQL($dbuser, $dbpasswd, "select * from cashaccts where id=?", $id);
		};
		$template->param(CASHACCTNAME => @acctinfo[1]);
		$template->param(CASHACCTVAL => @acctinfo[2]);
	} else {
		$template->param(TITLE => "Your Cash Accounts");
		$template->param(CASH => 1);
		my @accts;
		eval {
			@accts = ExecSQL($dbuser, $dbpasswd, "select * from cashaccts where id = (select distinct cashacct from stock_holdings where username = '?')", $user);
		};
		$out = "";
		foreach my $acct (@accts) {
			my ( $id, $accountname, $currentamt ) = @${$acct};
			$out .= "\t<dt><a href=\"index.pl?act=cash&id=" . $id . "\">" . $accountname . "</a></dt>\n\t<dd>" . $currentamt . "</dd>\n";
		}
		$template->param(CASHLIST_OUT => $out);
	}
} elsif ( $action eq "cashacctadd" ) {
	$template->param(LOGINSCREEN => 0);
	$template->param(CASHACCTADD => 1);
	$template->param(TITLE => "Add Cash Account");
	if ( param("cashacctaddrun") ) {
		my @err;
		my $acctname = param("acctname");
		my $amt = param("startval") + 0.0;
		eval {
			@err = ExecSQL($dbuser, $dbpasswd, "insert into cashaccts(accountname, currentamt, owner) values(?, ?, ?)", $acctname, $amt, $user);
		};
		$template->param(CASHACCTADDOK => 1);
	}
} elsif ( $action eq "strategies" ) {
	$template->param(LOGINSCREEN => 0);
	$template->param(TITLE => "Your Strategies");
}

#
# Generate debugging output if anything is enabled.
#
#
if ( $show_params || $show_cookies || $show_sqlinput || $show_sqloutput ) {
	print "<div style=\"text-align: left;\">";
    print hr, p, hr, p, h2('Debugging Output');
    if ($show_params) {
        print h3('Parameters');
        print "<ul>";
        print map { "<li>$_ => " . param($_) } param();
        print "</ul>";
        print h3('Template Parameters');
        print "<ul>";
        print map {"<li>$_ => " . $template->param($_) . "</li>"} $template->param();
        print "</ul>";
    }
    if ($show_cookies) {
        print h3('Cookies');
        print "<ul>";
        print map { "<li>$_ => " . cookie($_) } cookie();
        print "</ul>";
    }
    if ( $show_sqlinput || $show_sqloutput ) {
        my $max = $show_sqlinput ? $#sqlinput : $#sqloutput;
        print h3('SQL');
        print "<ul>";
        for ( my $i = 0 ; $i <= $max ; $i++ ) {
            if ($show_sqlinput)  { print "<li><b>Input:</b> $sqlinput[$i]"; }
            if ($show_sqloutput) { print "<li><b>Output:</b> $sqloutput[$i]"; }
        }
        print "</ul>";
    }
    print "</div>";
}

print $template->output;

#
#
# Check to see if user and password combination exist
#
# $ok = ValidUser($user,$password)
#
#
sub ValidUser {
    my ( $user, $password ) = @_;
    my @col;
    eval {
        @col =
          ExecSQL( $dbuser, $dbpasswd, "select count(*) from portfolio_users where username=? and pwd=?", "COL", $user, $password);
    };
    if ($@) {
        return 0;
    }
    else {
    	$template->param(LOGINFAILED => 0);
    	$template->param(LOGINSCREEN => 0);
    	$template->param(NAME => $user);
        return $col[0] > 0;
    }
}

#
# @list=ExecSQL($user, $password, $querystring, $type, @fill);
#
# Executes a SQL statement.  If $type is "ROW", returns first row in list
# if $type is "COL" returns first column.  Otherwise, returns
# the whole result table as a list of references to row lists.
# @fill are the fillers for positional parameters in $querystring
#
# ExecSQL executes "die" on failure.
#
sub ExecSQL {
    my ( $user, $passwd, $querystring, $type, @fill ) = @_;
    if ($show_sqlinput) {

 # if we are recording inputs, just push the query string and fill list onto the
 # global sqlinput list
        push @sqlinput,
          "$querystring (" . join( ",", map { "'$_'" } @fill ) . ")";
    }
    my $dbh = DBI->connect( "DBI:Oracle:", $user, $passwd );
    if ( not $dbh ) {

       # if the connect failed, record the reason to the sqloutput list (if set)
       # and then die.
        if ($show_sqloutput) {
            push @sqloutput,
              "<b>ERROR: Can't connect to the database because of "
              . $DBI::errstr . "</b>";
        }
        die "Can't connect to database because of " . $DBI::errstr;
    }
    my $sth = $dbh->prepare($querystring);
    if ( not $sth ) {

        #
        # If prepare failed, then record reason to sqloutput and then die
        #
        if ($show_sqloutput) {
            push @sqloutput,
              "<b>ERROR: Can't prepare '$querystring' because of "
              . $DBI::errstr . "</b>";
        }
        my $errstr = "Can't prepare $querystring because of " . $DBI::errstr;
        $dbh->disconnect();
        die $errstr;
    }
    if ( not $sth->execute(@fill) ) {

        #
        # if exec failed, record to sqlout and die.
        if ($show_sqloutput) {
            push @sqloutput,
                "<b>ERROR: Can't execute '$querystring' with fill ("
              . join( ",", map { "'$_'" } @fill )
              . ") because of "
              . $DBI::errstr . "</b>";
        }
        my $errstr =
            "Can't execute $querystring with fill ("
          . join( ",", map { "'$_'" } @fill )
          . ") because of "
          . $DBI::errstr;
        $dbh->disconnect();
        die $errstr;
    }

    #
    # The rest assumes that the data will be forthcoming.
    #
    #
    my @data;
    if ( defined $type and $type eq "ROW" ) {
        @data = $sth->fetchrow_array();
        $sth->finish();
        $dbh->disconnect();
        return @data;
    }
    my @ret;
    while ( @data = $sth->fetchrow_array() ) {
        push @ret, [@data];
    }
    if ( defined $type and $type eq "COL" ) {
        @data = map { $_->[0] } @ret;
        $sth->finish();
        $dbh->disconnect();
        return @data;
    }
    $sth->finish();
    $dbh->disconnect();
    return @ret;
}

sub UserAdd { 
 	my ($firstname, $lastname, $username, $pwd, $email) = @_;
 	eval { ExecSQL($dbuser,$dbpasswd,
		 "insert into portfolio_users (firstname,lastname,username,pwd,email) values (?,?,?,?,?)",undef,@_);};
	$outputcookiecontent = join( "/", $username, $pwd );
    $loginok = 1;
  	return $@;
}

sub DepositCash { 
  eval { ExecSQL($dbuser,$dbpasswd,
		 "update cashaccts set currentamt=currentamt+$depoist where accountname=$accname",undef,@_);
		 ExecSQL($dbuser,$dbpasswd,
		 "insert into transactions (cashacct,transtype,foramt) values (?,?,?)",undef,@_);};	 
  return $@;
}

sub WithdrawCash { 
  eval { ExecSQL($dbuser,$dbpasswd,
		 "update cashaccts set currentamt=currentamt-$depoist where accountname=$accname",undef,@_);
		 ExecSQL($dbuser,$dbpasswd,
		 "insert into transactions (cashacct,transtype,foramt) values (?,?,?)",undef,@_);};
  return $@;
}