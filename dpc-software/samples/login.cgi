#!/usr/bin/perl
# DPC System template CGI
our $CGI_file = 'login.cgi';
# Possibly useful line (replace admin-email):
# BEGIN { $ENV{'SERVER_ADMIN'} = 'admin-email'; }
#For debugging
use CGI::Carp 'fatalsToBrowser';
# user warnings;
use CGI::Carp;
#use strict;
use lib '.', 'dpc-software/bin';
use CGI qw(:standard);
use POSIX;
use Text::Starfish;
use DPC;
use CGI::AuthRegister;
require 'dpc-software/bin/dpc-lib.pl';
require 'configuration.pl';

#&early_limit_to_testing;

use vars qw($Error $ErrorInternal $Message $LogReport
	    $SessionId $Ticket $UserFirstName
	    $UserLastName $UserRole $UserEmail
	    $Page_first_part $Page_final_part $Page_content);
use subs qw(finish_page);

our $Title = $CompetitionId.' &mdash; Login Page';
our $H1    = $CompetitionId.' &mdash; Login Page';

CGI::AuthRegister::require_https;
&analyze_cookie;

#&limit_only_to_testing;
if ($SessionId ne '') {
    &myprint("<p>You are already logged in as $UserFirstName $UserLastName.\n".
	     "<p>To log out click here: <a href=\"logout.cgi\">logout</a>\n");
    &finish_page_and_exit;
}
if ($Error ne '')
{ &myprint($Error); $LogReport.="$Error\n$ErrorInternal\n"; $Error = $ErrorInternal = ''; }

if (param('request_type') eq 'password_reminder') {
    my $email = param('email_pw_remind'); $email = lc $email;
    my $u = &get_user_for_kv('email', $email);
    if ($u eq '') { $u = &get_user_for_kv('dpcid', $email); }
    if ($u eq '' or $u->{alternativeLoginAllowed} != 1) {
	$Error = 'Alternative login not registered for this email.';
	&print_form_and_finish; }
    dpc_send_email_reminder($email);
    if ($Error eq '') { &finish_page_and_exit; }
    else { &print_form_and_finish }
}
elsif ($AuthenticationType eq 'local' and param('request_type') eq 'login') {
    my $userid = param('userid'); my $password = param('password');
    my $email = $userid;
    $email =~ s/\(.*\)//g; $email =~ s/^\s+//; $email =~ s/\s+$//;
    #&login($email, $password);
    &login_email_or_dpcid($email, $password);
    &print_form_and_finish if $Error ne '';
    &myprint("<p>Hi $UserFirstName.  You are logged in.\n".
	     "<p>You can proceed and click here to look at ".
	     "the problems: <a href=\"problems.cgi\">Problems</a>\n"
	     );
    $LogReport.="User $UserFirstName $UserLastName <$UserEmail> logged in.";
    &finish_page_and_exit;
}
elsif (param('request_type') eq 'login') { die "not available..." }

# Empty request

# $Message = 'Enter your userid and password.';
$Message = '';
&print_form(); &finish_page_and_exit;
########################################################################

sub printforminputline {
    my $dispfield = shift;
    my $fieldname = shift;
    #my $value = param($fieldname); $value =~ s/["<>]//g;
    #my $r = "<tr><td>$dispfield:&nbsp;&nbsp;</td><td><input type=\"text\" name=\"$fieldname\" value=\"$value\"".
    #  " style=\"color:darkblue; font-family:Verdana, Geneva, Arial, ".
    #  "Helvetica, sans-serif; bold\"/></td></tr>\n";
    my $f;
    if ($fieldname =~ /password/i || $fieldname =~ /sitecode/i) {
	$f = password_field(-name=>$fieldname, -style=>"color:darkblue; font-family:Verdana, ".
		       "Geneva, Arial, Helvetica, sans-serif; bold");
    } else {
	$f = textfield(-name=>$fieldname,
		      -style=>"color:darkblue; font-family:Verdana, ".
		      "Geneva, Arial, Helvetica, sans-serif; bold");
    }
    my $r = "<tr><td>$dispfield:&nbsp;&nbsp;</td><td>$f</td></tr>\n";
    return $r;
}
       
sub print_form {
    my $r = '';
    $r.="<p><b>$Error</b></p>\n" if $Error ne '';
    $r.="<p><b>$Message</b></p>\n" if $Message ne '';

    $r.= "<table>\n";
    $r.= "<form name=\"login\" action=\"$HttpsBaseLink/$CGI_file\" method=\"post\">\n";
    $r.= "<input type=\"hidden\" name=\"request_type\" value=\"login\" />\n";
    #    "<input type=\"hidden\" name=\"send\" value=\"true\" />\n";
    # $r.= "<input type=\"hidden\" name=\"fail\" value=\"true\" />\n" if $fail;
    my $f = \&printforminputline;
    #if (!&isSubmissionOpen())
    #{ $r.='<tr><th> colspan="2">Practicum is closed at this time.</th></tr>'."\n"; }
    if ($AuthenticationType eq 'csid+site') {
	$r.= '<tr><th colspan="2">Login using CS userid, password, and site code:</th></tr>'."\n";
	$r.=&$f('CS Userid',   'csuserid');
	$r.=&$f('CS Password', 'cspassword');
	$r.=&$f('DPC Site Code', 'sitecode');
    } elsif ($AuthenticationType eq 'local') {
	$r.= '<tr><th colspan="2">Login using Userid or Email and password:</th></tr>'."\n";
	$r.=&$f('Userid or email', 'userid');
	$r.=&$f('Password',        'password');
    } else {
	$r.= '<tr><th colspan="2">Login using CSID and password:</th></tr>'."\n";
	$r.=&$f('CS Userid',   'csuserid');
	$r.=&$f('CS Password', 'cspassword');
    }

    $r.="<tr><td>&nbsp;</td><td>".
	"<input type=\"submit\" value=\"Login\" ".
	"style=\"color:black;font-family:Verdana, Geneva, Arial, ".
	"Helvetica, sans-serif;font-size: 11px;\" /></td></tr>\n";
    $r.="</form></table>\n";

    if ($AuthenticationType =~ /^csid\b/) {
    $r.="<p><b>Note:</b> Your CSID and password are different from your Dal ID ".
	"and password.\nAll CS students and all students registered in at least\n".
	"one CS course are assigned a CSID and password.\n".
	"You can check your CSID and password, or change your password, by following the ".
	"instructions at <a target=\"_blank\" ".
	"href=\"https://csid.cs.dal.ca/\">https://csid.cs.dal.ca</a>."; }

    if ($AuthenticationType eq 'csid,locA') {
	$r.= "<br><br><br><br><table border=1><tr><td>";
	$r.= "<table>\n";
	$r.= "<form name=\"login\" action=\"$HttpsBaseLink/$CGI_file\" method=\"post\">\n";
	$r.= "<input type=\"hidden\" name=\"request_type\" value=\"login\" />\n";
	my $f = \&printforminputline;
	$r.= '<tr><th colspan="2">Alternative Login for registered users, if you '.
	    'do not have a CSID:</th></tr>'."\n";
	$r.=&$f('Userid or email', 'userid');
	$r.=&$f('Password',        'password');

	$r.="<tr><td>&nbsp;</td><td>".
	    "<input type=\"submit\" value=\"Login\" ".
	    "style=\"color:black;font-family:Verdana, Geneva, Arial, ".
	    "Helvetica, sans-serif;font-size: 11px;\" /></td></tr>\n";
	$r.="</form></table>\n";

	$r.= "<p>If you forgot or do not know your password, \n".
	    "then you can submit your email below.  The password will be sent to you, ".
	    "if you are registered at the site before.\n";
	$r.="<table>\n";
	$r.= "<form name=\"password_reminder\" action=\"$HttpsBaseLink/$CGI_file\" method=\"post\">\n";
	$r.= "<input type=\"hidden\" name=\"request_type\" value=\"password_reminder\" />\n";
	$r.=&$f('E-mail', 'email_pw_remind');
	$r.="<tr><td>&nbsp;</td><td>".
	    "<input type=\"submit\" value=\"Send Password\" ".
	    "style=\"color:black;font-family:Verdana, Geneva, Arial, ".
	    "Helvetica, sans-serif;font-size: 11px;\" /></td></tr>\n";
	$r.="</form></table>\n";
	$r.="</td></tr></table>\n";
    }

    &myprint($r);
}

sub print_form_and_finish { &print_form; &finish_page; }

sub myprint { for (@_) { $Page_content.=$_ } }

sub finish_page {
    &load_template;
    &print_header;
    print $Page_first_part;
    print $Page_content;
    print $Page_final_part;
    if ($Error ne '') { &send_email_error }
    DPC::store_log if $LogReport ne '';
    exit;
}

sub finish_page_and_exit { &finish_page; exit; }
