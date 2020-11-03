#!/usr/bin/perl
# DPC System template CGI
our $CGI_file = 'contest.cgi';
# Possibly useful line (replace admin-email):
# BEGIN { $ENV{'SERVER_ADMIN'} = 'admin-email'; }
#For debugging
#use CGI::Carp 'fatalsToBrowser';
use CGI::Carp;
use strict;
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

our $Title    = "$CompetitionId &mdash; Contest";
our $H1       = "$CompetitionId &mdash; Contest";

&analyze_cookie;

if ($SessionId eq '') {
    &load_template; &print_header; print $Page_first_part;
    print "<p>You must be logged in to see this page.\n"; &finish_page;
}

&load_template; &print_header; print $Page_first_part;

print <<"EOT";
<h3>$CompetitionId</h3>
EOT

&finish_page;

sub finish_page {
    print $Page_final_part;
    if ($Error ne '') { &send_email_error }
    &store_log if $LogReport ne '';
    exit;
}
