#!/usr/bin/perl -w

use Time::ParseDate;

$user='cs339';
$pass='cs339';
$db='cs339';

use Getopt::Long;

$count=1;
$mindays=0;
$from=0;
$to=0;
&GetOptions("count=i"=>\$count, "mindays=i"=>\$mindays, "from=s"=>\$from, "to=s"=>\$to);


$sql="select symbol from symbols where count>$mindays";
if ($from) {
  $sql.=" and first<=".parsedate($from);
}
if ($to) {
  $sql.=" and last>=".parsedate($to);
}
$sql.=" order by rand() limit $count";

#print STDERR $sql, "\n";

system "mysql --batch --silent --user=$user --password=$pass --database=$db --execute='$sql'";

