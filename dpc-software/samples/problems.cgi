#!/usr/bin/perl
BEGIN { $ENV{'SERVER_ADMIN'} = 'vlado@dnlp.ca'; }
#For debugging
use CGI::Carp 'fatalsToBrowser';
use CGI::Carp;
#use strict;
use lib '.', 'dpc-software/bin';
use CGI qw(:standard);
use Text::Starfish;
use DPC;
require 'dpc-lib.pl';
require 'configuration.pl';

use vars qw($Error $Message $LogReport
  $SessionId $Ticket $UserFirstName $UserLastName $UserRole $UserEmail $UserId
  $Page_first_part $Page_final_part $Page_content @Problems
);
use subs qw(finish_page);

our $Title = $CompetitionId.' &mdash; Problems';
our $H1    = $Title;
our $CGI_file = 'problems.cgi';

&analyze_cookie;

$DenyMsg = 'You must be logged in to see the problems.' if $SessionId eq '';
$DenyMsg = "Access is not allowed: $AccessMessage" if !&isAccessAllowed();
if ($DenyMsg ne '') {
    &load_template; &print_header;
    print $Page_first_part, "<p>$DenyMsg\n"; &finish_page; }

my $t1;
if ($ProblemsAvailableAt =~ /^(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/) {
  my ($y,$m,$d,$h,$min,$s)=($1,$2,$3,$4,$5,$6);
  $t1 = mktime1($s,$min,$h,$d,$m,$y); }
my $tcurrent = time;
if (($UserRole ne 'admin') && ($tcurrent < $t1)) {
    $RefreshTime=60; &load_template; &print_header; print $Page_first_part;
    print "<p>No problems posted yet.\n";
    # print (($t1-$tcurrent)/60/60)." h"; # print_environment;
    &finish_page;
}

&load_problems;

my $keywords;
if (param() and ($keywords=param('keywords'))) {
    if ($keywords =~ /^(\w+)\.pdf$/) {
	my $id=$1; my @p = grep { $_->{id} eq $id } @Problems;
	my $file;
	if (@p && exists($p[0]->{pdf}))	{ $file = $p[0]->{pdf} }
	if ($file ne '' and -f $file) { &deliver_pdf("$id.pdf", $file) }
    }
    elsif ($keywords =~ /^(\w+)(-\d+)?\.(in|out)$/) {
	my $id=$1; my $mid=$2; my $ext=$3;
	my @p = grep { $_->{id} eq $id } @Problems;
	my $file;
	if (@p && -f "problems/data-sample/$id$mid.$ext" )
	{ &deliver_text("$id.$ext", "problems/data-sample/$id$mid.$ext") }
    }
    elsif ($keywords =~ /^other\/(\w+\.java)$/) {
	my $id=$1;
	if (-f "problems/other-files/$id" )
	{ &deliver_text("$id", "problems/other-files/$id") }
    }
#     elsif ($keywords eq 'all-submissions' && $UserIsJudge) { $ProduceAllSubmissions=1 }
#     elsif ($keywords eq 'current-results') { $ProduceCurrentResults=1 }
}

# To add condition for submission
if (&isSubmissionOpen and param() and
    param('submit_solution') eq 'Submit Solution') {
    my $filename = param('filename');
    my $language = param('language');
    my $problem  = param('problem');

    $RefreshTime = 5;
    &load_template; &print_header; print $Page_first_part;
    if (!&store_submission_new($filename,$language,$problem)) {
        print "<h3>Solution failed!</h3>\n";
	print "Error: $Error<br>\n";
    } else {
        print "<h3>Solution submitted!</h3>\n".
	    "Your solution has been successfully submitted.<br><br>\n";
	$LogReport.="User $UserFirstName $UserLastName <$UserEmail>\n".
	    "submitted solution to problem ($problem) in language ($language).";
    }
    print "<br><a href=\"problems.cgi\">Go back to the problems page.</a>\n";
    &finish_page;
}

$H1.= " (server time: ".strftime("%T", localtime(time)).")";
$RefreshTime=60; &load_template; &print_header; print $Page_first_part;
print "<h3>Problems:</h3>\n";

&print_problems;
if (scalar(@Problems) > 0) {
    &print_submission_part if &isSubmissionOpen;
    &print_your_submissions_new;
}

&finish_page;

sub print_problems {
    if (scalar(@Problems) == 0) { print "No problems posted yet.\n"; return; }

    # There should be some way of not showing problems before allowed

    my $print_problems = '';
    for my $p (@Problems) {
	$print_problems .= "<br>" unless $print_problems eq '';
	$print_problems.="$p->{id}: $p->{'Problem title'} ".
	    "(<a href=\"problems.cgi?$p->{id}.pdf\">$p->{id}.pdf</a>)";
	my $sampledata = '';
	if (-f "problems/data-sample/$p->{id}.in" )
	{ $sampledata.=" <a href=\"problems.cgi?$p->{id}.in\">$p->{id}.in</a>" }
	if (-f "problems/data-sample/$p->{id}.out" )
	{ $sampledata.=" <a href=\"problems.cgi?$p->{id}.out\">$p->{id}.out</a>" }
	for my $i (1..5) {
	    if (-f "problems/data-sample/$p->{id}-$i.in" )
	    { $sampledata.=" <a href=\"problems.cgi?$p->{id}-$i.in\">$p->{id}-$i.in</a>" }
	    if (-f "problems/data-sample/$p->{id}-$i.out" )
	    { $sampledata.=" <a href=\"problems.cgi?$p->{id}-$i.out\">$p->{id}-$i.out</a>" }
	}
	$print_problems.= " Sample data:$sampledata" unless $sampledata eq '';
	if (-f "problems/other-files/$p->{id}.java") {
	  $print_problems.=" Other: <a href=\"problems.cgi?other/$p->{id}.java\">".
	      "$p->{id}.java</a>"; }
	$print_problems.= "\n";
    }
    print $print_problems;
}

sub print_submission_part {
    my @problemlist = map { "$_->{id} - $_->{'Problem title'}" } @Problems;
    print "<p><table border=1><tr><td>\n";
    print start_multipart_form(-action=>'problems.cgi');
    print "<b>Solution submission:</b> ";
    print "\nSelect problem: ", popup_menu(-name=>'problem',
 				       -values=>[ @problemlist ]), "\n";
    print "\nLanguage: ", popup_menu(-name=>'language', -values=>\@PLanguages), "\n";
    print "\n<br>File:\n",
    filefield(-name=>"filename",-size=>60,-maxlength=>100),submit("submit_solution","Submit Solution");
    print end_form;
    print "<b>Note:</b> A solution program file should be named according to the problem ID.\n";
    #print "For example, a solution for problem Problem1 must be Problem1.java, for the programming ".
    #      "language Java.\n";
    print "For example, a solution for the problem A must be named ";
    if ($#PLanguages==0 && $PLanguages[0] eq 'C') {
	print "A.c in the language C."; }
    else {
	print "either A.java, A.c, A.cc,\n".
	    "or A.py, for languages Java, C, C++, or Python (2 or 3), ".
	    "respectively.<br>\n".
	    "The program must read input from the standard input and produce ".
	    "output to the standard output.\n";
    }
    print "\n";
    #if (grep {$_ eq 'Python'} @PLanguages) { print " (Or, A.py for Python)\n" }
    print "</td></tr></table>\n";
}
