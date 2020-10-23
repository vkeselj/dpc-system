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

our $Title = $CompetitionId.' &mdash; Code View';
our $H1    = $Title;
our $CGI_file = 'codeview.cgi';

&analyze_cookie;

$DenyMsg = 'You are not logged in.' if $SessionId eq '';
$DenyMsg = "Access is not allowed: $AccessMessage" if !&isAccessAllowed();
if ($DenyMsg ne '') {
    $Error .= "$DenyMsg\n";
    &load_template; &print_header;
    print $Page_first_part, "<p>$DenyMsg\n"; &finish_page; exit; }

if (!param()) {
  L_err:
    &load_template; &print_header; print $Page_first_part;
    print "<h3>Incorrect invocation ($CGI_file ERR-37).</h3>\n";
    print $Error;
    &finish_page; exit;
}

my $keywords = param('keywords');
my $stage;
if ($keywords =~ /,(.*)/) { $stage = $1; $keywords = $`; }
if ($keywords !~
    /(\d\d\d\d)(\d\d)(\d\d)T(\d\d)(\d\d)(\d\d)-(\w+)-(\w+)-(\w+)$/)
{ $Error.= "format!? ($keywords)\n"; goto L_err; }
my ($year,$mon,$day,$hour,$min,$sec,$userid,$lang,$prob) =
    ($1,$2,$3,$4,$5,$6,$7,$8,$9);

if ($UserRole ne 'admin' and $UserId ne $userid) {
    $Error .= "Access not allowed.\n"; goto L_err; }

my $subm = $keywords;
my %submissions = get_submissions();
if (!exists($submissions{$subm})) {
    $Error.= "submissions!? ($subm)\n"; goto L_err; }
my $dir = $submissions{$subm}->{dir};
my $problem = $submissions{$subm}->{prob};
my $language = $submissions{$subm}->{lang};
my $ext;
if    ($language eq 'C')      { $ext = ".c" }
elsif ($language eq 'CPP')    { $ext = ".cc" }
elsif ($language eq 'Java')   { $ext = ".java" }
elsif ($language eq 'Python') { $ext = ".py" }
elsif ($language eq 'Python2'){ $ext = ".py" }
elsif ($language eq 'Python3'){ $ext = ".py" }
elsif ($language eq 'Csharp') { $ext = ".cs" }
else                          { $ext = ".java" }
my $progfile = "$dir/$problem$ext";
if (!-f $progfile) {
    $Error.= "$CGI_file ERR-72.\n"; goto L_err; }
&load_template; &print_header; print $Page_first_part;
my $progfilec = getfile($progfile);
$progfilec = Text::Starfish::htmlquote($progfilec);

print "<h3>Submitted solution (p.lang.: $language, status: ".
    $submissions{$subm}->{status}.
    "):</h3>\n<h4>File name: $problem$ext</h4><pre>$progfilec</pre>\n";

&finish_page; exit;
