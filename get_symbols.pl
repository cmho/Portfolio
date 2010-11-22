#!/usr/bin/perl -w

$user='cs339';
$pass='cs339';
$db='cs339';

system "mysql --batch --silent --user=$user --password=$pass --database=$db --execute='select symbol from symbols;'";

