#!/usr/bin/perl
# DPC System template CGI
our $CGI_file = 'logout.cgi';
# Possibly useful line (replace admin-email):
# BEGIN { $ENV{'SERVER_ADMIN'} = 'admin-email'; }
#use strict;
use lib '.', 'dpc-software/bin';
use CGI qw(:standard);
#For debugging
#use CGI::Carp 'fatalsToBrowser';
use CGI::Carp;
#use POSIX;
use Text::Starfish;
use DPC;
require 'dpc-software/bin/dpc-lib.pl';
require 'configuration.pl';

use vars qw($Error $ErrorInternal $Message $LogReport
	    $SessionId $Ticket $Cookie $UserFirstName
	    $UserLastName $UserRole $UserEmail
	    $Page_first_part $Page_final_part $Page_content);

use subs qw(finish_page);

our $Title = $CompetitionId.' &mdash; Logout';
our $H1    = $CompetitionId.' &mdash; Logout';
our $CGI_file = 'logout.cgi';
&analyze_cookie;
$Cookie = '';

if ($SessionId ne '') { &logout; $Message = 'You are logged out.'; }
else { $Message = "$Error\n<p>You were not logged in." }

&finish_page;
########################################################################

sub myprint { for (@_) { $Page_content.=$_ } }

sub finish_page {
    &load_template;
    if ($Cookie ne '') { print header(-cookie=>$Cookie) } else { print header() }
    print $Page_first_part;
    print $Page_content;
    print "<p>$Message\n".
	"<p>To login again, click <a href=\"$HttpsBaseLink/login.cgi\">here</a>.\n".
	"<p>To go to the main page, click <a href=\"index.cgi\">here</a>.\n";
    print $Page_final_part;
    if ($Error ne '') { &send_email_error }
    &store_log if $LogReport ne '';
    exit;
}

sub finish_page_and_exit { &finish_page; exit; }
