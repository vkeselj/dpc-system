#!/usr/bin/perl
# DPC System template CGI
our $CGI_file = 'refs.cgi';
# Possibly useful line (replace admin-email):
# BEGIN { $ENV{'SERVER_ADMIN'} = 'admin-email'; }
#For debugging
#use CGI::Carp 'fatalsToBrowser';
use CGI::Carp;
#use strict;
use lib '.';
use CGI qw(:standard);
use Text::Starfish;
use lib 'dpc-software/bin';
use DPC;
require 'dpc-software/bin/dpc-lib.pl';
require 'configuration.pl';

use vars qw($Error $Message $SessionId $Ticket $UserFirstName $UserLastName $UserRole
	    $Page_first_part $Page_final_part $Page_content);
use subs qw(finish_page);

our $Title    = $CompetitionId.' &mdash; Language References';
our $H1       = $CompetitionId.' &mdash; Language References';
our $CGI_file = 'refs.cgi';

&analyze_cookie; &load_template; &print_header; print $Page_first_part;

# The language references are not packed with DPC System.  We could put add
# some links to external resources below.  During competitions, the internet
# connection should be blocked, with this web site being one exception, so
# in that case some language references should be copied here.
# I usually copy them in the parent directory of this directory and make
# "docs" a symbolic link pointing to that directory.  In this way, we do not
# have to copy the whole directory for each competition.
#
# If the directories "docs/java" etc. below exist, the links will show up
# in the page:

my $out = "<ul>\n";
if (-d "docs/java") { $out.= "<li> <a target=\"_blank\" href=\"".
       "docs/java\">Java Reference pages</a>\n" }
if (-d "docs/c")    { $out.= "<li> <a target=\"_blank\" href=\"".
       "docs/c\">C Reference pages (PDF)</a>\n" }
if (-d "docs/cppreference/en/c.html") {
       $out.= "<li> <a target=\"_blank\" href=\"".
       "docs/cppreference/en/c.html\">C Reference (from cppreference.com)".
       "</a>\n" }
if (-d "docs/cpp")  { $out.= "<li> <a target=\"_blank\" href=\"".
       "docs/cpp\">C++ Reference pages (PDF)</a>\n" }
if (-d "docs/cppreference/en/cpp.html") {
       $out.= "<li> <a target=\"_blank\" href=\"".
       "docs/cppreference/en/cpp.html\">C++ Reference (from cppreference.com)".
       "</a>\n" }
if (-d "docs/python-2.7/index.html") {
       $out.= "<li> <a target=\"_blank\" href=\"".
       "docs/python-2.7/index.html\">Python 2.7</a>\n" }
if (-d "docs/python-3.8/index.html") {
       $out.= "<li> <a target=\"_blank\" href=\"".
       "docs/python-3.8/index.html\">Python 3.8</a>\n" }
if ($out eq "<ul>\n") {
  $out.= "<li> No language references could be found.\n" }
$out.= "</ul>\n";

print $out;

&finish_page;

sub finish_page { print $Page_final_part; exit; }
