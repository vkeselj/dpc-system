#!/usr/bin/perl
BEGIN { $ENV{'SERVER_ADMIN'} = 'vlado@dnlp.ca'; }
#For debugging
use CGI::Carp 'fatalsToBrowser';
use CGI::Carp;
#use strict;
use lib '.';
use CGI qw(:standard);
use CGI::AuthRegister;
use Text::Starfish;
use lib 'dpc-software/bin';
use DPC;
require 'dpc-software/bin/dpc-lib.pl';
require 'configuration.pl';

use vars qw($Error $Message $SessionId $Ticket $UserFirstName $UserLastName $UserRole
	    $Page_first_part $Page_final_part $Page_content);
use subs qw(finish_page);

our $Title = $CompetitionHeaderTitle;
our $H1    = $CompetitionFullTitle;
our $CGI_file = 'index.cgi';

&analyze_cookie;
&load_template;
&print_header; print $Page_first_part;

#print "<pre>";
#for my $k (keys(%ENV)) { print "$k=$ENV{$k}\n"; }
#print "</pre>";

$_ = <<'EOT';
<b>This is a sample DPC contest.</b>

# Comments are ignored

EOT
s/^#.*\n//mg;
print;

&finish_page;
sub finish_page { print $Page_final_part; exit; }
