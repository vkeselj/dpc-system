#!/usr/bin/perl
# DPC System template CGI
our $CGI_file = 'clarifications.cgi';
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
require 'dpc-lib.pl';
require 'configuration.pl';

use vars qw($Error $Message $LogReport
  $SessionId $Ticket $UserFirstName $UserLastName $UserRole $UserEmail $UserId
  $Page_first_part $Page_final_part $Page_content @Problems
);
use subs qw(finish_page);

our $Title = $CompetitionId.' &mdash; Clarifications';
our $H1    = $Title;

&analyze_cookie;

$DenyMsg = 'You must be logged in to access this page.' if $SessionId eq '';
$DenyMsg = "Access is not allowed: $AccessMessage" if !&isAccessAllowed();
if ($DenyMsg ne '') {
    &load_template; &print_header;
    print $Page_first_part, "<p>$DenyMsg\n"; &finish_page; }

$RefreshTime=60; &load_template; &print_header; print $Page_first_part;

if ($UserRole ne 'admin') { }
# Open form for a new clarification
elsif (param() && param('New Clarification')) {
  print start_form(-action=>url(), -name=>"form_addclarification").
    textarea(-name=>"clarificationval",-default=>'',-rows=>10,-columns=>120)."<br/>\n".
    submit(-name=>"Add Clarification", -value=>'Add Clarification', -style=>"padding: 0").
    submit(-name=>"Cancel", -value=>'Cancel', -style=>"padding: 0").
    "</form>\n";
} elsif (param() && param('Add Clarification') &&     # Add a new clarification
	 param('clarificationval') ne '') {
    if (lock_mkdir('db/clarifications')) {
	my $claric;
	$claric = getfile('db/clarifications') if -f 'db/clarifications';
	my $clarnum = 0;
	while ($claric =~ /<h3>Clarification (\d+):/g) {
	    $clarnum = $1 if $1 > $clarnum; }
	++$clarnum;
	my $newclar = &htmlquote(param('clarificationval'));
	$claric = "<h3>Clarification $clarnum:</h3>\n$newclar\n$claric";
	putfile('db/clarifications', $claric);
	unlock_mkdir('db/clarifications');
	&print_new_clarification_button;
    } else { $Error = 'ERR-26: Cannot lock db/clarifications.' }
} else { &print_new_clarification_button }

&print_clarifications;

&finish_page; exit;

sub print_new_clarification_button {
    return unless $UserRole eq 'admin';
    print start_form(-action=>url(), -name=>"form_newclarification").
	submit(-name=>"New Clarification", -value=>'New Clarification').
	"</form>\n";
}

sub print_clarifications {
    if (!-r 'db/clarifications') {
	print "<h3>No clarifications so far</h3>\n"; }
    else {
	print getfile('db/clarifications');
    }
}
