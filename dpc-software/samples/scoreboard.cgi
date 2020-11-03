#!/usr/bin/perl
# DPC System template CGI
our $CGI_file = 'scoreboard.cgi';
# Possibly useful line (replace admin-email):
# BEGIN { $ENV{'SERVER_ADMIN'} = 'admin-email'; }
#For debugging
#use CGI::Carp 'fatalsToBrowser';
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
  $CompetitionId $CompetitionHeaderTitle $CompetitionFullTitle
);
use subs qw(finish_page);

our $Title    = $CompetitionId.' &mdash; Scoreboard';
our $H1       = $CompetitionId.' &mdash; Scoreboard';

&analyze_cookie;

if (!$ScoreboardPublic and $Session eq '')
{ $DenyMsg = 'You must be logged in to access this page.' }
if (!$ScoreboardPublic and !&isAccessAllowed()) {
  $DenyMsg = "Access is not allowed: $AccessMessage" }
if ($DenyMsg ne '') {
    &load_template; &print_header;
    print $Page_first_part, "<p>$DenyMsg\n"; &finish_page; }

$H1.= " (server time: ".strftime("%T", localtime(time)).")";
&load_template; &print_header; print $Page_first_part;

&print_current_results_new;

&finish_page;

sub finish_page {
    print $Page_final_part;
    if ($Error ne '') { &send_email_error }
    &store_log if $LogReport ne '';
    exit;
}
