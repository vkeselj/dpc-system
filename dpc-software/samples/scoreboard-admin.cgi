#!/usr/bin/perl
# DPC System template CGI
our $CGI_file = 'scoreboard-admin.cgi';
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
  $Page_first_part $Page_final_part $Page_content @Problems %Team @TeamsRanked
);
use subs qw(finish_page);

our $Title = $CompetitionId.' &mdash; Admin Scoreboard';
our $H1    = $CompetitionId.' &mdash; Admin Scoreboard';

&DPC::analyze_cookie;

if ($SessionId eq '' or $UserRole ne 'admin') {
#if ($SessionId eq '') {
    &load_template; &print_header; print $Page_first_part;
    print "<p>No permission to view the page.\n"; &finish_page;
}

$RefreshTime=30;
$H1.= " (server time: ".strftime("%T", localtime(time)).")";
&load_template; &print_header; print $Page_first_part;

DPC::print_admin_scoreboard;

&finish_page;

sub finish_page {
    print $Page_final_part;
    if ($Error ne '') { &send_email_error }
    &store_log if $LogReport ne '';
    exit;
}
