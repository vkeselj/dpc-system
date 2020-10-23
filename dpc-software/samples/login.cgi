#!/usr/bin/perl
our $CGI_file = 'login.cgi';
BEGIN { $ENV{'SERVER_ADMIN'} = 'vlado@dnlp.ca'; }
#For debugging
# use CGI::Carp 'fatalsToBrowser';
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
elsif (param('request_type') eq 'login') {
    my $csuserid = param('csuserid'); my $cspassword = param('cspassword');
    my $userid = param('userid'); my $password = param('password');
    my $email = $userid;
    $email =~ s/\(.*\)//g; $email =~ s/^\s+//; $email =~ s/\s+$//;

    if ($AuthenticationType eq 'csid+site') {
      $csuserid =~ s/\([^)]*\)/ /g; $csuserid =~ s/^\s+//; $csuserid =~ s/\s+$//;
      $csuserid = lc $csuserid;
      if ($csuserid eq '') {
	$Error = 'CS userid empty.';
	$ErrorInternal = "CS userid empty.";
	&print_form_and_finish;
      }
      my $user = &get_user_for_kv('csuserid', $csuserid);
      if ($user eq '') {
	$Error = 'CS userid not registered.';
	$ErrorInternal = "CS userid ($csuserid) not in users.db. (ERR-68)";
	&print_form_and_finish;
      }
      if ($user->{roles} ne 'scoreboard' &&
	  CGI::AuthRegisterFCS::password_check_ldap($csuserid,$cspassword)!=1) {
	$Error = 'CS userid and password not correct (CS password not confirmed by LDAP).';
	$ErrorInternal = "CS userid ($csuserid) did not pass LDAP.";
	&print_form_and_finish;
      }

      if (!&isSubmissionOpen() && $user->{roles} !~ /\badmin\b/) {
	$Error = 'Practicum closed.';
	&print_form_and_finish;
      }

      &set_random_displayids;
      &set_random_sitecodes;

      $user->{sitecode} =~ s/\s//g;
      if ($user->{roles} !~ /\badmin\b/ && $user->{sitecode} ne param('sitecode')) {
	$Error = 'Authentication unsuccessful (incorrect DPC Site Code, use the code given in the instruction sheet).';
	my $s = $user->{sitecode}; $s1 = param('sitecode');
	$ErrorInternal = "CS userid ($csuserid) sitecode not correct (ERR-85):\n".
	  "expected=($s) given=($s1)";
	&print_form_and_finish;
      }

      if ($user->{email} eq '') {
	&myprint($Error='Internal error: no email (ERR-78)');
	&print_form_and_finish; }
      $email = $user->{email};
      $LogReport.="User $UserFirstName $UserLastName <$UserEmail> logged in.";
      &set_new_session_for_email($email);
    }

    elsif ($AuthenticationType eq 'csid+db') {
      $csuserid =~ s/\([^)]*\)/ /g; $csuserid =~ s/^\s+//;
      $csuserid =~ s/\s+$//; $csuserid = lc $csuserid;
      if ($csuserid eq '') {
	$Error = 'CS userid empty.';
	$ErrorInternal = "CS userid empty.";
	&print_form_and_finish;
      }
      my $user = &get_user_for_kv('csuserid', $csuserid);
      if ($user eq '') {
	$Error = 'CS userid not registered.';
	$ErrorInternal = "CS userid ($csuserid) not in users.db. (ERR-68)";
	&print_form_and_finish;
      }
      if ($user->{roles} ne 'scoreboard' &&
	  CGI::AuthRegisterFCS::password_check_ldap($csuserid,$cspassword)!=1) {
	$Error = 'CS userid and password not correct (CS password not confirmed by LDAP).';
	$ErrorInternal = "CS userid ($csuserid) did not pass LDAP.";
	&print_form_and_finish;
      }

      if (!&isAccessAllowed() && $user->{roles} !~ /\badmin\b/) {
	$Error = "Access not allowed: $AccessMessage";
	&print_form_and_finish;
      }

      &set_random_displayids;

      if ($user->{email} eq '') {
	&myprint($Error='Internal error: no email (ERR-78)');
	&print_form_and_finish; }
      $email = $user->{email};
      $LogReport.="User $UserFirstName $UserLastName <$UserEmail> logged in.";
      &set_new_session_for_email($email);

    } else {
        if ($csuserid ne '') {
	$csuserid =~ s/\([^)]*\)/ /g; $csuserid =~ s/^\s+//; $csuserid =~ s/\s+$//;
	$csuserid = lc $csuserid;
	use CGI::AuthRegisterFCS;
        if (CGI::AuthRegisterFCS::password_check_ldap($csuserid,$cspassword)!=1) {
	  $Error = 'CS userid and password not correct (LDAP).';
	  $ErrorInternal = "CS userid ($csuserid) did not pass LDAP.";
	  &print_form_and_finish;
	}
	my $user = &get_user_for_kv('csuserid', $csuserid);
        if ($user eq '') { $user = &get_user_for_kv('dpcid', $csuserid); }
        if ($user eq '') {
	  #$email = $csuserid.'_CSID@dnlp.ca';
	  $email = $csuserid.'@cs.dal.ca';
	  if (&get_user_for_email($email) eq '') {
	    # &myprint('TODO.'); &print_form_and_finish; $Error='err'; exit;
	    my @users = @{ &read_db('file=db/users.db') }; my $flag='';
	    for (@users) { if ($_->{email} eq $email) { $flag=1 } }
	    if ($flag) { &myprint('Email exists.'); &print_form_and_finish; }
	    for (@users) { if ($_->{dpcid} eq $csuserid) { $flag=1 } }
	    if ($flag) { &myprint('dpcid exists.'); &print_form_and_finish; }
	    my $record;
	    $record = "dpcid:$csuserid\ncsuserid:$csuserid\n".
	      "firstname:$csuserid\n".
	      #"lastname:$csuserid\nemail:$email\nroles:competitor\n";
	      "lastname:\nroles:competitor\n";
	    my $usersfile = getfile("db/users.db")."\n\n$record";
	    $usersfile =~ s/\n\n\n+/\n\n/g;
	    putfile("db/users.db", $usersfile);
	    &set_random_displayids;
	  }
	}
        DPC::set_new_session_for_kv('dpcid', $csuserid);
	#&set_new_session_for_email($email);
      } else {
        # Check for registration, added for ICPC-open 2019-11-13
        my $u = &get_user_for_kv('email', $email);
        if ($u eq '') { $u = &get_user_for_kv('dpcid', $email); }
        if ($u eq '' or $u->{alternativeLoginAllowed} != 1) {
	   $Error = 'Alternative login not registered for this email.';
	   &print_form_and_finish; }
        &login($email, $password);
      }
    }
    &print_form_and_finish if $Error ne '';
    &myprint("<p>Hi $UserFirstName.  You are logged in.\n".
	     "<p>You can proceed and click here to look at the problems: ".
	     "<a href=\"problems.cgi\">Problems</a>\n" );
    $LogReport .= "User $UserFirstName $UserLastName <$UserEmail> logged in.";
    &finish_page_and_exit;
  }

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
