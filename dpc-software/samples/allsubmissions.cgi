#!/usr/bin/perl
# DPC System template CGI
our $CGI_file = 'allsubmissions.cgi';
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
require 'dpc-software/bin/dpc-lib.pl';
require 'configuration.pl';

use vars qw($Error $Message $LogReport
  $SessionId $Ticket $UserFirstName $UserLastName $UserRole $UserEmail $UserId
  $Page_first_part $Page_final_part $Page_content @Problems
);
use subs qw(finish_page);

our $Title = $CompetitionId.' &mdash; All Submissions';
our $H1    = $Title;

&analyze_cookie;

if ($SessionId eq '' or $UserRole ne 'admin') {
    &load_template; &print_header; print $Page_first_part;
    print "<p>No permission to view the page.\n"; &finish_page;
}

my $keywords; my %args;
if (param() and ($keywords=param('keywords'))) {
    if ($keywords =~ /\bnot-judged-only\b/) {
	$args{'not-judged-only'} = 1;
	$Title = $H1 = $CompetitionId.' &mdash; Not Judged Submissions';
    }
}

&load_template; &print_header; print $Page_first_part;

print "Options: <a href=\"allsubmissions.cgi\">All</a> ".
    "<a href=\"allsubmissions.cgi?not-judged-only\">not-judged-only</a>\n<p>\n";

&print_all_submissions_new(%args);

&finish_page;
