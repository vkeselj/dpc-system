#!/usr/bin/perl
# DPC System template CGI
our $CGI_file = 'feedbackview.cgi';
# Possibly useful line (replace admin-email):
# BEGIN { $ENV{'SERVER_ADMIN'} = 'admin-email'; }
#For debugging
use CGI::Carp 'fatalsToBrowser';
use CGI::Carp;
#use strict;
use lib '.', 'dpc-software/bin';
use CGI qw(:standard);
use Text::Starfish;
use DPC;
use DPC::Feedback;
require 'dpc-lib.pl';
require 'configuration.pl';

use vars qw($Error $ErrorInternal $Message $LogReport
  $SessionId $Ticket $UserFirstName $UserLastName $UserRole $UserEmail $UserId
  $Page_first_part $Page_final_part $Page_content @Problems
);
use subs qw(finish_page);

our $Title = $CompetitionId.' &mdash; Feedback View';
our $H1    = $Title;

&analyze_cookie;

$DenyMsg = 'You are not logged in.' if $SessionId eq '';
$DenyMsg = 'Feedback not allowed by configuration.' if !$Feedback;
$DenyMsg = "Access is not allowed: $AccessMessage" if !&isAccessAllowed();
if ($DenyMsg ne '') {
    $Error .= "$DenyMsg\n";
    &load_template; &print_header;
    print $Page_first_part, "<p>$DenyMsg\n"; &finish_page; exit; }

if (!param()) {
  L_err:
    &load_template; &print_header; print $Page_first_part;
    print "<h3>Incorrect invocation ($CGI_file ERR-36).</h3>\n";
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
my $datetime = "$1$2$3T$4$5$6";

if ($UserRole ne 'admin' and $UserId ne $userid) {
    $Error .= "Access not allowed.\n"; goto L_err; }

my $subm = $keywords;
my %submissions = get_submissions();
if (!exists($submissions{$subm})) {
    $ErrorInternal .= "$CGI_file E-56: submission does not exist.\n".
	"\tsubmission=($subm)\n";
    $Error.= "E-56: Invalid parameter.\n"; goto L_err; }
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
my $status = $submissions{$subm}->{status};
my $judgec;
if (-f "$dir/judge.log") { $judgec=DPC::getfile_limit("$dir/judge.log") }

#$judgec =~ s/[\x80-\xFF]/'=x'.unpack("H2",$&)/ge;
$judgec =~ s/\xE2\x80\x98/`/g;
$judgec =~ s/\xE2\x80\x99/'/g;

print "<h3>Feedback on Solution (p.lang.: $language, status: ".
    $status."):</h3>\n";

my $feedback;

$feedback = DPC::Feedback::gen_feedback(-feedback=>$feedback,
  -problem=>$problem, -judgec=>$judgec, -status=>$status,
  -language=>$language, -subm=>$subm);

#$feedback.= "<pre>".Text::Starfish::htmlquote($judgec)."</pre>\n";

print "<pre>".Text::Starfish::htmlquote($feedback)."</pre>\n";
print "<h4>Submitted Solution: $problem$ext</h4>\n".
 "<pre>$progfilec</pre>\n";

# # Email debug info
# if ('') {
#  my $debug = "Feedback provided for solution in:\n";
#  DPC::debug($debug.
#    " $dir\n\n".('-'x72)."\nFeedback: $feedback".
#   ('-'x72)."\njudge.log:\n$judgec\n".
#   "\nSubmitted Solution: $problem$ext\n\n$progfilec"
#      );
# }

&finish_page; exit;
