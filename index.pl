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
if ( $action eq "login" || param('loginrun') ) {
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
        }
        else {

            # uh oh.  Bogus login attempt.  Make him try again.
            # don't give him a cookie
            $logincomplain = 1;
            $action        = "login";
        }
    }
    else {

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
        }
    }
    else {

        #
        # He has no cookie and must log in.
        #
        $action = "login";
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
}

if ( $action eq "logout" ) {
    $template->param(LOGOUTSUCCESS => 1);
    $template->param(LOGINSCREEN => 1);
}

# QUERY
#
# Query is a "normal" form.
#
#
if ( $action eq "overview" ) {
	$template->param(JUSTLOGGEDIN => 1);
	$template->param(NAME => $user);
}
if ( $action eq "portfoliolist" ) {
    #
    # check to see if user can see this
    #
    $template->param(PORTFOLIOS => 1);
    my @res;
    eval {
    	@res = ExecSQL($dbuser, $dbpasswd, "select name from stock_holdings where userid='" . $user . "'");
    };
}

# WRITE
#
# Write is a "normal" form.
#
#
if ( $action eq "write" ) {

    #
    # check to see if user can see this
    #
    if ( !UserCan( $user, "write-messages" ) ) {
        print h2('You do not have the required permissions to write messages.');
    }
    else {

        #
        # Generate the form.
        # Your reply functionality will be similar to this
        #
        print start_form( -name => 'Write' ),
          h2('Make blog entry'), "Subject:", textfield( -name => 'subject' ),
          p("Upload image:"), p filefield('imgupload', '', 50, 80),
          p
          textarea(
            -name    => 'post',
            -default => 'Write your post here.',
            -rows    => 16,
            -columns => 80
          ),
          hidden( -name => 'postrun', -default => ['1'] ),
          hidden( -name => 'act',     -default => ['write'] ), p submit,
          end_form,
          hr;

        #
        # If we're being invoked with parameters, then
        # do the actual posting.
        #
        if ( param('postrun') ) {
        	
        	my $filename ;
	    	if (param('imgupload')) {
	    		my $filechars = "a-zA-Z0-9_.-";
				my $filedir = "/home/cmh736/public_html/microblog/uploads/";
				
				my $q = new CGI;
				$filename = $q->param('imgupload');
				
				if ($filename) {
					my ( $name, $path, $extension ) = fileparse( $filename, '\..*' );  
					$filename = $name . $extension;
					
					$filename =~ tr/ /_/;  
					$filename =~ s/[^$filechars]//g;
					
					if ( $filename =~ /^([$filechars]+)$/ ) {  
						$filename = $1;  
					} else {  
						die "Filename contains invalid characters";  
					}
					
					my $fh = $q->upload('imgupload');
					
					open ( UPLOADFILE, ">$filedir/$filename" ) or die "$!";  
					binmode UPLOADFILE;  
					 
					while ( <$fh> ) {  
						print UPLOADFILE;  
					}  
					 
					close UPLOADFILE;
				}
	    	}
        	
            my $by      = $user;
            my $text    = param('post');
            my $subject = param('subject');
            my $img 	= param('imgupload');
            my $error   = Post( 0, $by, $subject, $text, $img );
            if ($error) {
                print "Can't post message because: $error";
            }
            else {
                print "Posted the following on $subject from $by:<p>$text";
            }
        }
    }
}
if ( $action eq "reply" ) {
	my $id = param('id');
    #
    # check to see if user can see this
    #
    if ( !UserCan( $user, "write-messages" ) ) {
        print h2('You do not have the required permissions to write messages.');
    }
    else {

        #
        # Generate the form.
        # Your reply functionality will be similar to this
        #
        print start_form( -name => 'reply' ),
          h2('Post Reply:'), "Subject:", textfield( -name => 'subject' ),
          p("Upload image:"), p filefield('imgupload', '', 50, 80),
          p textarea(
            -name    => 'post',
            -default => 'Write your reply here.',
            -rows    => 16,
            -columns => 80
          ),
          hidden( -name => 'respid',  -default => $id ),
          hidden( -name => 'postrun', -default => ['1'] ),
          hidden( -name => 'act',     -default => ['reply'] ), p submit,
          end_form,
          hr;

        #
        # If we're being invoked with parameters, then
        # do the actual posting.
        #
        if ( param('postrun') ) {
        
        	        	my $filename ;
	    	if (param('imgupload')) {
	    		my $filechars = "a-zA-Z0-9_.-";
				my $filedir = "/home/cmh736/public_html/microblog/uploads/";
				
				my $q = new CGI;
				$filename = $q->param('imgupload');
				
				if ($filename) {
					my ( $name, $path, $extension ) = fileparse( $filename, '\..*' );  
					$filename = $name . $extension;
					
					$filename =~ tr/ /_/;  
					$filename =~ s/[^$filechars]//g;
					
					if ( $filename =~ /^([$filechars]+)$/ ) {  
						$filename = $1;  
					} else {  
						die "Filename contains invalid characters";  
					}
					
					my $fh = $q->upload('imgupload');
					
					open ( UPLOADFILE, ">$filedir/$filename" ) or die "$!";  
					binmode UPLOADFILE;  
					 
					while ( <$fh> ) {  
						print UPLOADFILE;  
					}  
					 
					close UPLOADFILE;
				}
	    	}
        	
            my $by      = $user;
            my $respid	= param('respid');
            my $text    = param('post');
            my $subject = param('subject');
            my $img		= param('imgupload');
            my ($out, $error) = Post( $respid, $by, $subject, $text, $img );
            if ($error) {
                print "Can't post message because: $error";
            }
            else {
                print "Posted the following on $subject from $by:<p>$text";
            }
        }
    }
}
if ( $action eq "view" ) {
	my $id = param('id');
	my ($out, $error) = ViewMessage($id);
	if ($error) {
		print "Can't view message because: $error";
	}
	else {
		print $out;
	}
}

# USERS
#
# Adding and deleting users is a couple of normal forms
#
#
if ( $action eq "users" ) {

    #
    # check to see if user can see this
    #
    if ( !UserCan( $user, "manage-users" ) ) {
        print h2('You do not have the required permissions to manage users.');
    }
    else {

        #
        # Generate the add form.
        #
        print start_form( -name => 'AddUser' ),
          h2('Add User'),
          "Name: ", textfield( -name => 'name' ),
          p,
          "Email: ", textfield( -name => 'email' ),
          p,
          "Password: ", textfield( -name => 'password' ),
          p,
          hidden( -name => 'adduserrun', -default => ['1'] ),
          hidden( -name => 'act',        -default => ['users'] ),
          submit,
          end_form,
          hr;

        #
        # Generate the givepermform.
        #
        print start_form( -name => 'GivePermission' ),
          h2('Give Permission'),
          "Name: ", textfield( -name => 'name' ),
          p,
          "Action: ", textfield( -name => 'perm' ),
          hidden( -name => 'givepermrun', -default => ['1'] ),
          hidden( -name => 'act', -default => ['users'] ), p,
          submit,
          end_form,
          hr;

        #
        # Generate the revokepermform.
        #
        print start_form( -name => 'RevokePermission' ),
          h2('Revoke Permission'),
          "Name: ", textfield( -name => 'name' ),
          p,
          "Action: ", textfield( -name => 'perm' ),
          hidden( -name => 'revokepermrun', -default => ['1'] ),
          hidden( -name => 'act', -default => ['users'] ), p,
          submit,
          end_form,
          hr;

        #
        # Generate the deleteform.
        # Your delete message functionality may be similar to this
        #
        print start_form( -name => 'DeleteUser' ),
          h2('Delete User'),
          "Name: ", textfield( -name => 'name' ),
          p,
          hidden( -name => 'deluserrun', -default => ['1'] ),
          hidden( -name => 'act',        -default => ['users'] ),
          submit,
          end_form,
          hr;

        #
        # Run the user add
        #
        if ( param('adduserrun') ) {
            my $name     = param('name');
            my $email    = param('email');
            my $password = param('password');
            my $error;
            $error = UserAdd( $name, $password, $email );
            if ($error) {
                print "Can't add user because: $error";
            }
            else {
                print "Added user $name $email\n";
            }
        }

        #
        # Run the user delete
        #
        if ( param('deluserrun') ) {
            my $name  = param('name');
            my $error = UserDel($name);
            if ($error) {
                print "Can't delete user because: $error";
            }
            else {
                print "User $name deleted.";
            }
        }

        #
        # Run givepermission
        #
        if ( param('givepermrun') ) {
            my $name  = param('name');
            my $perm  = param('perm');
            my $error = GiveUserPerm( $name, $perm );
            if ($error) {
                print "Can't give $name permission $perm because: $error";
            }
            else {
                print "User $name given permission $perm.";
            }
        }

        #
        # Run givepermission
        #
        if ( param('revokepermrun') ) {
            my $name  = param('name');
            my $perm  = param('perm');
            my $error = RevokeUserPerm( $name, $perm );
            if ($error) {
                print "Can't revoke $name permission $perm because: $error";
            }
            else {
                print "User $name has had permission $perm revoked.";
            }
        }

        #
        # Print tables users Permissions
        #
        my ( $table, $error );
        ( $table, $error ) = PermTable();
        if ($error) {
            print "Can't display permissions table because: $error";
        }
        else {
            print "<h2>Available Permissions</h2>$table";
        }
        ( $table, $error ) = UserTable();
        if ($error) {
            print "Can't display user table because: $error";
        }
        else {
            print "<h2>Registered Users</h2>$table";
        }
        ( $table, $error ) = UserPermTable();
        if ($error) {
            print "Can't display user permission table because: $error";
        }
        else {
            print "<h2>Users and their permissions</h2>$table";
        }
    }
}
if ( $action eq "delete" ) {
	if ( !UserCan( $user, "delete-any-messages" ) ) {
        print h2('You do not have the required permissions to delete this post.');
    }
    else {
    	if ( param('id') ) {
    		my $id = param('id');
    		my ($out, $error) = DeleteMessage($id);
    		print $out;
    	}
    	else {
    		print h2('No post specified for deletion.');
    	}
    }
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