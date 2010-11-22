#!/usr/bin/perl -wcT

use lib '/home/cmh736/public_html/portfolio/';
use warnings;
use strict;
use CGI qw(:standard);
use CGI;
use CGI::Carp qw (fatalsToBrowser);
use File::Basename;
use DBI;
use Mysql;
use HTML::Template;
use Data::Serializer;
use Time::ParseDate;

$CGI::POST_MAX = 1024 * 5000;

$ENV{ORACLE_HOME}="/opt/oracle/product/11.2.0/db_1";
$ENV{ORACLE_BASE}="/opt/oracle/product/11.2.0/db_1";
$ENV{ORACLE_SID}  = "CS339";

my $dbuser   = "cmh736";
my $dbpasswd = "o04604475";

my $template = HTML::Template->new(filename => 'portfolio.tmpl');

my $action;

if (param("act")) {
	$action = param("act");
} else {
	$action = "login";
}

if ($action == "login") {
	$template->param('title') = "Login";
}