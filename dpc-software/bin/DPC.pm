# DPC Software. DPC Main module, Vlado Keselj 2010-2020
# Search for :section to find the main sections
#use strict;
package DPC;
use vars qw($NAME $ABSTRACT $VERSION);
$NAME     = 'DPC';
$ABSTRACT = 'dpc-system - DPC System for Programming Contests and Practicums';
$VERSION  = '1.2004';

use vars (
  '%Chmod', # defined if needed to chmod some dirs or files
            # eg: $DPC::Chmod{'sessiond'} = 0770;  
  '%Chgrp', # defined if needed to chgrp some dirs or files
            # eg: $DPC::Chgrp{'sessiond'} = 'vlado'  
);
package main;
use vars (
  qw($RemoteUser $UserIsJudge
  @Problems @ProblemsLetterTitle @ProblemIds %ProblemById),
  '%Team',        # Information about all teams
  '@TeamsRanked', # Team ids ranked by results
  qw($BaseDir $CompetitionId @Accounts
  $DPC_email_from $DPC_email_bcc
  $Error $ErrorInternal $Feedback $FreezeFlag $Message $LogReport
  $CGI_file $Page_first_part $Page_final_part $Page_content
  ),
  '$LoginEmail',   # LoginEmail used to log in. It should be the same as
	           # $UserEmail, but could have differences such as
	           # uppercase or lowercase letters. Maybe it should be the
	           # same as $UserEmail.(todo?)
  qw($SessionId $Ticket $Cookie %Session
  $UserFirstName $UserLastName $UserRole @UserRoles $UserEmail $UserId
));


sub afterStartTime {
    if ($Cache_afterStartTime ne '') {
	if ($Cache_afterStartTime eq 'yes') { goto L_yes }
	else { goto L_no }
    }
    if ($CompetitionStartTime =~ /^(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/) {
	my ($y,$m,$d,$h,$min,$s)=($1,$2,$3,$4,$5,$6);
	my $t1 = mktime1($s,$min,$h,$d,$m,$y);
	my $tcurrent = time;
	if ($tcurrent < $t1) { goto L_no; }
    }
    goto L_yes;
  L_yes: $Cache_afterStartTime = 'yes'; return 1;
  L_no:  $Cache_afterStartTime = 'no'; return '';
}

sub afterEndTime {
    if ($Cache_afterEndTime ne '') {
	if ($Cache_afterEndTime eq 'yes') { goto L_yes }
	else { goto L_no }
    }
    if ($CompetitionEndTime =~ /^(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/) {
	my ($y,$m,$d,$h,$min,$s)=($1,$2,$3,$4,$5,$6);
	my $t1 = mktime1($s,$min,$h,$d,$m,$y);
	my $tcurrent = time;
	if ($tcurrent > $t1) { goto L_yes; }
    }
    goto L_no;
  L_yes: $Cache_afterEndTime = 'yes'; return 1;
  L_no:  $Cache_afterEndTime = 'no'; return '';
}

sub isAccessAllowed {
    if ($Cache_isAccessAllowed ne '') {
	if ($Cache_isAccessAllowed eq 'yes') { goto L_yes }
	else { goto L_no }
    }
    goto L_yes if $UserRole eq 'admin';
    if (!$ContestOpen) { $AccessMessage = 'Contest closed'; goto L_no; }
    if (!&afterStartTime) {
	$AccessMessage = "To be open at $CompetitionStartTime";
	goto L_no; }
    if (&afterEndTime) {
	if ($AllowViewAfterEndTime) {
	    $AccessMessage = "Closed at $CompetitionEndTime.\n".
		"Login allowed, but not submissions.";
	    goto L_yes; }
	$AccessMessage = "Closed at $CompetitionEndTime";
	goto L_no; }
    goto L_yes;
  L_yes: $Cache_isAccessAllowed = 'yes'; return 1;
  L_no:  $Cache_isAccessAllowed = 'no'; return '';
}

sub isSubmissionOpen {
    if ($Cache_isSubmissionOpen ne '') {
	if ($Cache_isSubmissionOpen eq 'yes') {
	  return 1; }
	else {
	  $Cache_isSubmissionOpen = 'no'; return ''; }
    }
 
    if ($UserRole eq 'admin') { goto L_yes }
    if (!$SubmissionOpen) { goto L_no }
    if (!&afterStartTime) { goto L_no }
    if (&afterEndTime)    { goto L_no }
    goto L_yes;
  L_yes:
    $Cache_isSubmissionOpen = 'yes'; return 1;
  L_no:
    $Cache_isSubmissionOpen = 'no'; return '';
}

sub store_submission_new {
    my $filename = shift; my $language = shift; my $problem = shift;
    if ($filename eq '') { $Error='No submission.'; return ''; }
    my $submissiontime = $^T;
    my $timestamp = strftime("%Y%m%dT%H%M%S", localtime($submissiontime));
    my $ipnumber = $ENV{'REMOTE_ADDR'}; $ipnumber =~ s/\s//g;

    # Verify programming language
    if (!(grep {$_ eq $language} @PLanguages)) {
	$Error.="<b>Error! Language unknown or not allowed: (".
                &htmlsanitize($language).")</b>\n";
	return '';
    }
    if ($language eq 'C++') { $language = 'CPP' }
    if ($language eq 'C#')  { $language = 'Csharp' }

    # Verify problem
    if ($problem !~ /^\s*(\w+)/){
	$Error.="<b>Error!? Invalid problem ID (".&htmlsanitize($problem).").</b>\n";
	return '';
    }
    $problem = $1;
    if (!exists($ProblemById{$problem})) {
	$Error.="<b>Error!? Invalid problem ID (".&htmlsanitize($problem).").</b>\n";
	return '';
    }

    # Choose filename
    # Require certain file name
    my $expectedfilename = $problem;
    if    ($language eq 'C')      { $expectedfilename.= ".c" }
    elsif ($language eq 'CPP')    { $expectedfilename.= ".cc" }
    elsif ($language eq 'Java')   { $expectedfilename.= ".java" }
    elsif ($language eq 'Python') { $expectedfilename.= ".py" }
    elsif ($language eq 'Python2'){ $expectedfilename.= ".py" }
    elsif ($language eq 'Python3'){ $expectedfilename.= ".py" }
    elsif ($language eq 'Csharp') { $expectedfilename.= ".cs" }
    else                          { $expectedfilename.= ".java" }

    my $filenameloc = $expectedfilename;
    #my $filenameloc = $filename; $filenameloc =~ s/[\/|<>;&@]|\s/-/g;
    my $filenamehtml = &htmlsanitize($filename);
    #&print_environment;
    if ($filenameloc eq 'META.info') {
	$Error.="<b>Error!? Invalid file name: $filenamehtml</b>\n";
	return '';
    }
    if ($filenameloc ne $expectedfilename) {
	$Error.="<b>Error!? The file name is `$filenamehtml' instead of `$expectedfilename',\n".
	    "as expected by the choice of problem and language.</b>\n";
	return '';
    }

    #my $storedir = 'submissions';
    my $cm = 0700; # using sessionid, not need for separate id for submissions
    if (defined($DPC::Chmod{'sessiond'})) {
      $cm = $DPC::Chmod{'sessiond'}; umask ~$cm; }
    my $gid;
    if (defined($DPC::Chgrp{'sessiond'})) {
      $gid = getgrnam($DPC::Chgrp{'sessiond'}); }

    for my $storedir1 ('submissions', 'submissions-bak') {
      my $storedir = $storedir1;
      if (!-d $storedir && !(mkdir $storedir, $cm)) {
	$Error.='Problem storing submissions!? Please contact the administrator.';
	$ErrorInternal.="Cannot mkdir $storedir: $!";
	return '';
      }
      chown $>, $gid, $storedir if $gid;
      $storedir.= "/$UserId";
      if (!-d $storedir && !(mkdir $storedir, $cm)) {
	$Error.='Problem storing submissions!? Please contact the administrator.';
	$ErrorInternal.="Cannot mkdir $storedir: $!";
	return '';
      }
      chown $>, $gid, $storedir if $gid;
      $storedir.= "/$timestamp-$language-$problem";
      if (!-d $storedir && !(mkdir $storedir, $cm)) {
	$Error.='Problem storing submissions!? Please contact the administrator.';
	$ErrorInternal.="Cannot mkdir $storedir: $!";
	return '';
      }
      chown $>, $gid, $storedir if $gid;
      local *O; if ( !open(O, ">$storedir/$filenameloc") ) {
	$Error.='Problem storing the submission!? Please contact the administrator.';
	$ErrorInternal.="Error: Cannot write to $storedir/$filenameloc: $!";
	return '';
      }
      &lock_ex(*O); my ($bytesread, $buffer, $bytes);
      while ($bytesread = read($filename, $buffer, 1024))
	{ print O $buffer; $bytes+=$bytesread; }
      close (O);
      chmod $cm, "$storedir/$filenameloc";
      chown $>, $gid, "$storedir/$filenameloc" if $gid;
      local *M; open(M, ">$storedir/META.info") or croak; &lock_ex(*M);
	# Store submission meta-data template into file META.info
	print M "Timestamp:$timestamp\nLanguage:$language\nProblem:$problem\n".
	    "UserId:$UserId\nUserEmail:$UserEmail\nIPnumber:$ipnumber\n".
	    "#Comment: Keep only one status uncommented\n".
	    "Status:not judged yet\n".
	    "#Status:Solution Accepted!\n".
	    "#Status:Compilation Error\n".
	    "#Status:Incorrect Output\n".
	    "#Status:Time Limit Exceeded\n".
	    "#Status:Run-time Error\n";
      close(M);
      chmod $cm, "$storedir/META.info";
      chown $>, $gid, "$storedir/META.info" if $gid;
    }
    return 1;
} # end of sub store_submission_new

########################################################################
#:section HTML Preparation Routines

# Moving to DPC::print_all_submissions_new
sub print_all_submissions_new { return DPC::print_all_submissions_new(@_) }
sub DPC::print_all_submissions_new {
    my %args = @_;
    return unless $UserRole eq 'admin';
    my %submissions = get_submissions();
    print "<table border=1>".
	"<tr><th>Submission time</th><th>User</th><th>Problem</th>".
	"<th>Language</th><th>Status</th>".
	($Feedback?"<th>Feedback</th>":'').
	"<th>AdminView</h>".
	"</tr>\n";
    for my $subm (sort {$b cmp $a} keys(%submissions)) {
	my $hour = $submissions{$subm}->{hour};
	my $min  = $submissions{$subm}->{min};
	my $sec  = $submissions{$subm}->{sec};
	my $day  = $submissions{$subm}->{day};
	my $mon  = $submissions{$subm}->{month};
	my $year = $submissions{$subm}->{year};
	my $userid = $submissions{$subm}->{userid};
	my $prob   = $submissions{$subm}->{prob};
	my $lang   = $submissions{$subm}->{lang};
	my $status = $submissions{$subm}->{status};
	if ($args{'not-judged-only'} && $status ne 'not judged yet') { next }
	print "<tr>";
	print "<td><a href=\"codeview.cgi?$subm\">".
	    "$hour:$min:$sec&nbsp;$day-$mon-$year</a></td>";
	print "<td>$userid</td>".
	    "<td>Problem&nbsp;$prob</td>".
	    "<td align=center>$lang</td><td>$status</td>".
	    ($Feedback?("<td><a href=\"feedbackview.cgi?$subm\">feedback</a>".
			"</td>"):'').
	    "<td><a href=\"adminview.cgi?$subm\">adminview</a></td>".
	    "</tr>\n";
	# print "($UserId)";
    }
    print "</table>\n";
}

sub print_all_submissions {
    my %solutions = &get_solutions();
    my @submissions = sort keys (%solutions);
    print "<p>All submissions:<br>\n".
	"<table border=1><tr><th>Submission time</th><th>User</th>".
	"<th>Problem</th><th>Language</th><th>Status</th></tr>\n";
    for my $subm (sort {$b cmp $a} @submissions) {
	next unless $subm=~/^(\d\d\d\d)(\d\d)(\d\d)T(\d\d)(\d\d)(\d\d)-(\w+)-(\w+) (\w+)/;
	my ($year,$mon,$day,$hour,$min,$sec,$lang,$prob,$uid) = ($1,$2,$3,$4,$5,$6,$7,$8,$9);
	print "<tr><td>$hour:$min:$sec $day-$mon-$year</td><td>$uid</td>".
	    "<td>Problem $prob</td><td align=center>$lang</td>".
	    "<td>$solutions{$subm}->{status}</td></tr>\n";
    }
    print "</table>\n";
}

# 2011-04-27
sub print_your_submissions_new {
    my %submissions = &get_submissions("userid=$UserId");
    print "<p>Your submissions:<br><table border=1>".
	"<tr><th>Submission time</th><th>Problem</th><th>Language</th>".
	"<th>Status</th>".
	($Feedback?"<th>Feedback</th>":'').
	"</tr>\n";
    for my $subm (sort {$b cmp $a} keys(%submissions)) {
	my $hour = $submissions{$subm}->{hour};
	my $min  = $submissions{$subm}->{min};
	my $sec  = $submissions{$subm}->{sec};
	my $day  = $submissions{$subm}->{day};
	my $mon  = $submissions{$subm}->{month};
	my $year = $submissions{$subm}->{year};
	my $userid = $submissions{$subm}->{userid};
	my $prob   = $submissions{$subm}->{prob};
	my $lang   = $submissions{$subm}->{lang};
	my $status = $submissions{$subm}->{status};
	print "<tr>".
	    "<td><a href=\"codeview.cgi?$subm\">$hour:$min:$sec ".
	      "$year-$mon-$day</a></td>\n<td>Problem $prob</td>".
	    "<td align=center>$lang</td><td>$status</td>".
	    ($Feedback?("<td><a href=\"feedbackview.cgi?$subm\">".
			"feedback</a></td>"):'').
	    "</tr>\n";
    }
    print "</table>\n";
}


# eg: $t = mktime1($sec,$min,$h,$d,$m,$y); #eg $y='2010';
# eg: if ($CompetitionStartTime =~ /^(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/) {
#       my ($y,$m,$d,$h,$min,$s)=($1,$2,$3,$4,$5,$6);
#       $starttime = mktime1($s,$min,$h,$d,$m,$y);
#     }
sub mktime1 {
    use POSIX;
    #mktime(sec, min, hour, mday, month, year, wday=0, yday=0, isdst=0);
    my ($sec, $min, $h, $mday, $month, $year) = @_;
    $year = $year - 1900; $month=$month-1;
    return POSIX::mktime($sec, $min, $h, $mday, $month, $year, 0, 0, -1);
}

sub print_current_results_new() {
    &calculate_results();
    # Printing starts here
    my $currenttime = strftime("%Y-%m-%d %H:%M:%S", localtime($^T));
    my $r; $r="<b>Competition Start Time: $CompetitionStartTime";
    $r.=" &nbsp;&nbsp;Current: $currenttime";
    $r.=" &nbsp;&nbsp;End Time: $CompetitionEndTime</b><br>\n";
    print $r; $r='';
    if ($FreezeFlag) { print "<b>Scoreboard frozen at: $ScoreboardFreezeTime</b><br>\n" }
    if (!&isSubmissionOpen()) { print "<b>Submissions closed.</b><br>\n" }

    print "<TABLE border=\"1\">\n";
    print "<tr><th><strong><u>Rank</u></strong></th><th><strong><u>ID</u></strong></th>".
	"<th><strong><u>Solved</u></strong></th><th><strong><u>Time</u></strong></th>\n";
    for my $prob (@ProblemIds)
    { print "<th>&nbsp;&nbsp;&nbsp;&nbsp;<strong><u>$prob</u></strong>&nbsp;&nbsp;&nbsp;&nbsp;</th>\n" }
    print "<th>Total solv/att</th>\n"; # <th>Comments</th></tr>\n";
    if (ref($ScoreEval) eq 'CODE') {
	if ($ScoreHeader eq '') { $ScoreHeader = "Score" }
	print "<th>$ScoreHeader</th>\n";
    }
    print "</tr>\n";

    for my $team (@TeamsRanked) {
	next unless $Team{$team}->{competitor};
	#next unless $Team{$team}->{total_att} > 0;
	#++$rank;
	my $rank = $Team{$team}->{rank};

	my $problemssolved = $Team{$team}->{problems_solved};
	if ($problemssolved < 1) { $problemssolved = '0' }

	my $totaltime = &soltime2str($Team{$team}->{total_time});
	my $disp = $Team{$team}->{displayidshow};

	print "<tr><td align=center>$rank</td><td>$disp</td>".
	    "<td align=center>$problemssolved</td>".
	    "<td align=center>$totaltime</td>"; #time
	    #"<td align=center>$Team{$team}->{total_time}</td>"; #time
	    for my $prob (@ProblemIds) {
		my $e;
		if (exists($Team{$team}->{"problem_$prob td"}))
		{ $e = $Team{$team}->{"problem_$prob td"} }
		elsif (exists($Team{$team}->{"prob_att_$prob"}))
		{ $e = $Team{$team}->{"prob_att_$prob"}." att" }
		else { $e = "0 att" }
		if ($Team{$team}->{"problem_$prob td not judged"})
		{ print "<td align=center bgcolor=yellow>$e</td>" }
		elsif ($Team{$team}->{"problem_$prob td judging"})
		{ print "<td align=center bgcolor=red>$e</td>" }
		else { print "<td align=center>$e</td>" }
	    }
	print "<td align=center> $problemssolved / ".
	    $Team{$team}->{total_att}."</td>";
	if (ref($ScoreEval) eq 'CODE') {
	    if ($Team{$team}->{score} eq '') { $Team{$team}->{score} = 0; }
	    print "<td align=center>$Team{$team}->{score}</td>"; }
	# Additional column comment
	#if ($Team{$team}->{problems_solved} > 0) {
	#    print $Team{$team}->{firstname};
	#} 
	print "</tr>\n";
    }

    print "</table>\n";
}

sub DPC::print_admin_scoreboard() {
    &calculate_results();
##    ###########
##    &load_problems; # @Problems @ProblemIds %ProblemById
##    my %solutions = &get_submissions();
##
##    my %Team;
##    $BaseDir = '.' unless $BaseDir ne '';
##    die "no file $BaseDir/db/users/db" unless -f "$BaseDir/db/users.db";
##    for my $user (@{&read_db("file=$BaseDir/db/users.db")}) {
##	croak "empty userid" if $user->{dpcid} eq '';
##	croak "duplicate dpcid: ($user->{dpcid})" if exists($Team{$user->{dpcid}});
##	$userid = $user->{dpcid};
##	$Team{$userid} = $user;
##	my @roles = split(/\s*,\s*/, $Team{$userid}->{roles});
##	if ( grep {$_ eq 'competitor'} @roles )
##	{ $Team{$userid}->{competitor} = 1 }
##	else { $Team{$userid}->{competitor} = '' }
##    }
##    
##    my %tmp; for my $k (keys %solutions)
##    { next unless $Team{$solutions{$k}->{userid}}->{competitor}; $tmp{$k} = $solutions{$k}; }
##    %solutions = %tmp;
##
##    #mktime(sec, min, hour, mday, month, year, wday=0, yday=0, isdst=0);
##    my $starttime = 0; my $freezetime = 0; my $freezetimeS = '';
##    if (-f "$BaseDir/configuration.pl") {
##	require "$BaseDir/configuration.pl";
##	#$CompetitionStartTime='2011-03-19 09:06:00';
##	if ($CompetitionStartTime =~ /^(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/) {
##	    my ($y,$m,$d,$h,$min,$s)=($1,$2,$3,$4,$5,$6);
##	    $starttime = mktime1($s,$min,$h,$d,$m,$y);
##	}
##	# $ScoreboardFreezeTime='2011-05-12 23:20:30';
##	if ($ScoreboardFreezeTime =~ /^(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/) {
##	    my ($y,$m,$d,$h,$min,$s)=($1,$2,$3,$4,$5,$6);
##	    $freezetime = mktime1($s,$min,$h,$d,$m,$y);
##	    $freezetimeS = $ScoreboardFreezeTime;
##	}
##    }
##
    my $printtime = sub {
	use POSIX;
	my $sec = shift; $sec = 0 if $sec eq '';
	my $min;   if ($sec >= 60) { $min = POSIX::floor($sec/60); $sec %= 60; }
	my $hours; if ($min >= 60) { $hours = POSIX::floor($min/60); $min %= 60; }
	my $days;  if ($hours >= 24) { $days = POSIX::floor($hours/24); $hours %= 24; }
	my $totaltime = ($days>0 ? "${days}days " : '').($hours>0 ? "${hours}:" : '');
	$totaltime.= sprintf("%02d:%02ds",$min, $sec);
	return $totaltime;
    };
##
##    my $freezeflag = '';
##    for my $sol (sort(keys (%solutions))) {
##	my $year = $solutions{$sol}->{year};
##	my $mon  = $solutions{$sol}->{month};
##	my $day  = $solutions{$sol}->{day};
##	my $hour = $solutions{$sol}->{hour};
##	my $min  = $solutions{$sol}->{min};
##	my $sec  = $solutions{$sol}->{sec};
##	my $lang = $solutions{$sol}->{lang};
##	my $prob = $solutions{$sol}->{prob};
##	my $uid  = $solutions{$sol}->{userid};
##	my $status = $solutions{$sol}->{status};
##	my $soltime = mktime1($sec,$min,$hour, $day, $mon, $year);
##	if ($freezetime > 0 && $soltime > $freezetime && $UserRole ne 'admin')
##	{ $freezeflag = 1; next; }
##	if (!exists($Team{$uid})) { $Team{$uid} = { problems_solved => 0 } }
##	++$Team{$uid}->{total_att};
##	++$Team{$uid}->{"prob_att_$prob"};
##	if ($status =~ /\bsolution accepted\b/i) {
##	    if (!exists($Team{$uid}->{"problem_$prob"})) {
##		$Team{$uid}->{"problem_$prob"} = 'solved';
##		$Team{$uid}->{problems_solved} += 1;
##		if ($starttime == 0) { $starttime = mktime1($sec,$min,$hour, $day, $mon, $year) }
##		$Team{$uid}->{total_time} += mktime1($sec,$min,$hour, $day, $mon, $year) - $starttime;
##		$Team{$uid}->{"problem_$prob td"} = '';
##		if (time - $starttime > 86400)
##		{ $Team{$uid}->{"problem_$prob td"}.= sprintf("%04d-%02d-%02d ",$year,$mon,$day) }
##		$Team{$uid}->{"problem_$prob td"}.= sprintf("%02d:%02d:%02d",$hour,$min,$sec);
##
##	    }
##	} elsif ($status =~ /\bnot judged yet\b/) {
##	    $Team{$uid}->{"problem_$prob td not judged"} = 1;
##	}
##    }
    
##    if ($freezeflag) { print "<b>Scoreboard frozen at: $freezetimeS</b><br>\n" }
##    if (!&isSubmissionOpen()) { print "<b>Practicum closed.</b><br>\n" }

    # Printing starts here
    my $currenttime = strftime("%Y-%m-%d %H:%M:%S", localtime($^T));
    my $r; $r="<b>Competition Start Time: $CompetitionStartTime";
    $r.=" &nbsp;&nbsp;Current: $currenttime";
    $r.=" &nbsp;&nbsp;End Time: $CompetitionEndTime</b><br>\n";
    print $r; $r='';
    if ($FreezeFlag) { print "<b>Scoreboard frozen at: $ScoreboardFreezeTime</b><br>\n" }
    if (!&isSubmissionOpen()) { print "<b>Submissions closed.</b><br>\n" }

    print "<TABLE border=\"1\">\n";
    print "<tr><th><strong><u>Rank</u></strong></th><th><strong><u>ID</u></strong></th>".
	"<th><strong><u>Solved</u></strong></th><th><strong><u>Time</u></strong></th>\n";
    for my $prob (@ProblemIds)
    { print "<th>&nbsp;&nbsp;&nbsp;&nbsp;<strong><u>$prob</u></strong>&nbsp;&nbsp;&nbsp;&nbsp;</th>\n" }
    print "<th>Total solv/att</th>\n"; # <th>Comments</th></tr>\n";

    for my $k (keys(%Team)) {
	if (!exists($Team{$k}->{displayid})) { $Team{$k}->{displayid} = $k }
    }

    my $cmp = sub {
	my $a=shift; my $b=shift; my $ta = $Team{$a}; my $tb = $Team{$b};
	if ($ta->{problems_solved} < $tb->{problems_solved}) { return 1 }
	if ($ta->{problems_solved} > $tb->{problems_solved}) { return -1 }
	if ($ta->{total_time} > $tb->{total_time}) { return 1 }
	if ($ta->{total_time} < $tb->{total_time}) { return -1 }
	if ($ta->{total_att} < $tb->{total_att}) { return 1 }
	if ($ta->{total_att} > $tb->{total_att}) { return -1 }
	return $ta->{displayid} cmp $tb->{displayid};
    };
		    
    for my $team (@TeamsRanked) {
	next unless $Team{$team}->{competitor};
	#next unless $Team{$team}->{total_att} > 0;
	#++$rank;
	my $rank = $Team{$team}->{rank};

	my $problemssolved = $Team{$team}->{problems_solved};
	if ($problemssolved < 1) { $problemssolved = '0' }

	my $totaltime = &$printtime($Team{$team}->{total_time});
	# use POSIX;
	# my $sec = $Team{$team}->{total_time}; $sec = 0 if $sec eq '';
	# my $min;   if ($sec >= 60) { $min = POSIX::floor($sec/60); $sec %= 60; }
	# my $hours; if ($min >= 60) { $hours = POSIX::floor($min/60); $min %= 60; }
	# my $days;  if ($hours >= 24) { $days = POSIX::floor($hours/24); $hours %= 24; }
	# my $problemssolved = $Team{$team}->{problems_solved};
	# if ($problemssolved < 1) { $problemssolved = '0' }
	# my $totaltime = ($days>0 ? "${days}days " : '').($hours>0 ? "${hours}:" : '');
	# $totaltime.= sprintf("%02d:%02ds",$min, $sec);

	my $userid = $Team{$team}->{dpcid};

	print "<tr><td align=center>$rank</td>".
	    "<td>$Team{$team}->{displayidshow} ($userid)</td>".
	    "<td align=center>$problemssolved</td>".
	    "<td align=center>$totaltime</td>"; #time
	    #"<td align=center>$Team{$team}->{total_time}</td>"; #time
	    for my $prob (@ProblemIds) {
		my $e;
		if (exists($Team{$team}->{"problem_$prob td"}))
		{ $e = $Team{$team}->{"problem_$prob td"} }
		elsif (exists($Team{$team}->{"prob_att_$prob"}))
		{ $e = $Team{$team}->{"prob_att_$prob"}." att" }
		else { $e = "0 att" }
		if ($Team{$team}->{"problem_$prob td not judged"})
		{ print "<td align=center bgcolor=yellow>$e</td>" }
		else { print "<td align=center>$e</td>" }
	    }
	print "<td align=center> $problemssolved / ".
	    $Team{$team}->{total_att}."</td><td>";
	# Additional column comment
	#if ($Team{$team}->{problems_solved} > 0) {
	#    print $Team{$team}->{firstname};
	#} 
	print "</tr>\n";
    }

    print "</table>\n";
}


sub print_icpc_export() {
    &calculate_results();
    # Printing starts here
    if ($FreezeFlag) { print "Scoreboard frozen at: $ScoreboardFreezeTime\n" }
    if (!&isSubmissionOpen()) { print "Submissions closed.\n" }

    print "teamId,rank,medalCitation,problemsSolved,totalTime,".
	"lastProblemTime,siteCitation,citation\n";

    for my $team (@TeamsRanked) {
	next unless $Team{$team}->{competitor};
	my $rank = $Team{$team}->{rank};

	my $problemssolved = $Team{$team}->{problems_solved};
	if ($problemssolved < 1) { $problemssolved = '0' }

	my $totaltimeS = $Team{$team}->{total_time};
	my $totaltimeM = int($totaltimeS/60+0.5);
	my $totaltime = &soltime2str($Team{$team}->{total_time});

	my $icpcId = $Team{$team}->{icpcId};
	my $lastProblemTime = $Team{$team}->{'lastProblemTime'};
	$lastProblemTime = 0 if $lastProblemTime eq '';
	$lastProblemTime = int($lastProblemTime/60+0.5);

	my $siteCitation = $CompetitionFullTitle; $siteCitation=~s/"//g;
	print "$icpcId,$rank,,$problemssolved,$totaltimeM,$lastProblemTime,".
	    $siteCitation.",\n";
    }
}

sub print_marks() {
    &calculate_results();
    if ($FreezeFlag) { print "# Scoreboard frozen at: $freezetimeS\n" }

    for my $team (@TeamsRanked) {
	next unless $Team{$team}->{competitor};
	my $rank = $Team{$team}->{rank};
	my $problemssolved = $Team{$team}->{problems_solved};
	if ($problemssolved < 1) { $problemssolved = '0' }
	my $totaltime = &soltime2str($Team{$team}->{total_time});
	if ($Team{$team}->{score} eq '') { $Team{$team}->{score} = 0; }
	my $score = $Team{$team}->{score};
	my $ft = $Team{$team}->{first_time};

	print "\nopen(F,\">$team/marker-a4q5.txt\") or die; print F <<'EOT';\n";
	print "Userid: $team\n";
	print "Marker: Alicia Wong\n";
	print "A4Q5 mark (out of 20): (To Be Marked)\n";
	print "Comments:\n";
	if ($Team{$team}->{"problem_D"} eq 'solved') {
	    print "  Problem D of Practicum 2 accepted: 15/15\n"; }
	else { print "  Problem D of Practicum 2 not accepted: 0/15\n"; }
	# if ($problemssolved == 1) {
	#     print "Comments: $problemssolved problem solved in Practicum 3\n"; }
	# else { print "Comments: $problemssolved problems solved in Practicum 3\n"; }
	# if ($problemssolved > 0) {
	#     print " Your practicum rank is: $rank\n";
	#     if ($ft > 90*60) {
	#	print " -2 for not submitting the first problem in the first 1.5 hours\n";
	#    }
	#}
	print "EOT\nclose(F);\n";
    }
}

sub load_problems {
    @Problems = (); @ProblemIds = (); %ProblemById = ();
    for my $metaf (<problems/descriptions/*.meta>) {
	my @tmp = @{ &read_db("file=$metaf") };
	my $pstruc = $tmp[0];
	$metaf =~ /\/(\w+)(-[^\/]*)?\.meta$/ or next;
	my $problemid = $pstruc->{id} = $1;
	if (-e "problems/descriptions/$problemid.pdf")
	{ $pstruc->{pdf} = "problems/descriptions/$problemid.pdf" }
	push @Problems, $pstruc; push @ProblemIds, $problemid;
	$ProblemById{$problemid} = $pstruc;
    }
}

# Version 2011-04-27 for dpc/h 2011
# &get_submissions; &get_submissions("userid=x");
sub get_submissions {
    my $userid;
    if ($#_ > -1 && $_[0] =~ /^userid=(\S+)/) { $userid = $1 }
    if ($userid ne '' && !&useridcheckok($userid))
    { $ErrorInternal="Invalid userid ($userid)"; &send_email_error; return (); }
    my (%submissions, @submissiondirs);
    if ($userid eq '')
    { @submissiondirs = ($CompetitionDir eq '' ? <submissions/*/*> : <$CompetitionDir/submissions/*/*>) }
    else
    { @submissiondirs = ($CompetitionDir eq '' ? <submissions/$userid/*> : <$CompetitionDir/submissions/$userid/*>) }
    # submissions/userid/yyyyddmmThhmmss-lang-prob
    for my $subm (@submissiondirs) {
	next unless $subm=~/\/(\S+?)\/(\d\d\d\d)(\d\d)(\d\d)T(\d\d)(\d\d)(\d\d)-(\w+)-(\w+)$/;
	my ($userid,$year,$mon,$day,$hour,$min,$sec,$lang,$prob) = ($1,$2,$3,$4,$5,$6,$7,$8,$9);
	my $status = 'not judged yet';
	if (-e "$subm/META.info") {
	    my $c = &getfile("$subm/META.info");
	    if ($c=~/^Status:\s*(.*)/m) { $status = $1; }
	}
	my $key = "$year$mon${day}T$hour$min$sec-$userid-$prob-$lang";
	$submissions{$key} = { dir=>$subm, userid=>$userid,
	    submittime=>"$year$mon${day}T$hour$min$sec", lang=>$lang, prob=>$prob,
	    year=>$year,month=>$mon,day=>$day,hour=>$hour,min=>$min,sec=>$sec,
	    key=>$key, status=>$status };
    }
    return %submissions;
}

# Moving to DPC::calculate_results
sub calculate_results { return DPC::calculate_results(@_) }
sub DPC::calculate_results() {
    &load_problems; # @Problems @ProblemIds %ProblemById
    my %solutions = &get_submissions();

    %Team = ();
    $BaseDir = '.' unless $BaseDir ne '';
    die "no file $BaseDir/db/users/db" unless -f "$BaseDir/db/users.db";
    for my $user (@{&read_db("file=$BaseDir/db/users.db")}) {
      croak "empty userid" if $user->{dpcid} eq '';
      croak "duplicate dpcid: ($user->{dpcid})" if exists($Team{$user->{dpcid}});
	$userid = $user->{dpcid};
	$Team{$userid} = $user;
	my @roles = split(/\s*,\s*/, $Team{$userid}->{roles});
	if ( grep {$_ eq 'competitor'} @roles )
	{ $Team{$userid}->{competitor} = 1 }
	else { $Team{$userid}->{competitor} = '' }
    }
    
    my %tmp; for my $k (keys %solutions)
    { next unless $Team{$solutions{$k}->{userid}}->{competitor}; $tmp{$k} = $solutions{$k}; }
    %solutions = %tmp;

    #mktime(sec, min, hour, mday, month, year, wday=0, yday=0, isdst=0);
    my $starttime = 0; my $freezetime = 0; my $freezetimeS = '';
    if (-f "$BaseDir/configuration.pl") {
	require "$BaseDir/configuration.pl";
	#$CompetitionStartTime='2011-03-19 09:06:00';
	if ($CompetitionStartTime =~ /^(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/) {
	    my ($y,$m,$d,$h,$min,$s)=($1,$2,$3,$4,$5,$6);
	    $starttime = mktime1($s,$min,$h,$d,$m,$y);
	}
	# $ScoreboardFreezeTime='2011-05-12 23:20:30';
	if ($ScoreboardFreezeTime =~ /^(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/) {
	    my ($y,$m,$d,$h,$min,$s)=($1,$2,$3,$4,$5,$6);
	    $freezetime = mktime1($s,$min,$h,$d,$m,$y);
	    $freezetimeS = $ScoreboardFreezeTime;
	}
    }

    $FreezeFlag = '';
    for my $sol (sort(keys (%solutions))) {
	my $year = $solutions{$sol}->{year};
	my $mon  = $solutions{$sol}->{month};
	my $day  = $solutions{$sol}->{day};
	my $hour = $solutions{$sol}->{hour};
	my $min  = $solutions{$sol}->{min};
	my $sec  = $solutions{$sol}->{sec};
	my $lang = $solutions{$sol}->{lang};
	my $prob = $solutions{$sol}->{prob};
	my $uid  = $solutions{$sol}->{userid};
	my $status = $solutions{$sol}->{status};
	my $soltime = mktime1($sec,$min,$hour, $day, $mon, $year);
	if ($freezetime > 0 && $soltime > $freezetime && $UserRole ne 'admin')
	{ $FreezeFlag = 1; next; }
	if (!exists($Team{$uid})) { $Team{$uid} = { problems_solved => 0 } }
	++$Team{$uid}->{total_att};
	++$Team{$uid}->{"prob_att_$prob"};
	if ($status =~ /\bsolution accepted\b/i) {
	    if (!exists($Team{$uid}->{"problem_$prob"})) {
		$Team{$uid}->{"problem_$prob"} = 'solved';
		$Team{$uid}->{problems_solved} += 1;
		my $psolved = $Team{$uid}->{problems_solved};
		if ($starttime == 0) { $starttime = mktime1($sec,$min,$hour, $day, $mon, $year) }
		my $utime = mktime1($sec, $min, $hour, $day, $mon, $year);
		$Team{$uid}->{"problem_$prob utime"} = $utime;
		my $ptime = $utime - $starttime;
		$Team{$uid}->{'lastProblemTime'} = $ptime;
		my $previous_attempts = $Team{$uid}->{"prob_att_$prob"} - 1;
		$Team{$uid}->{total_time} += $ptime;
		# Additing penalty for previous incorrect attempts:
		$Team{$uid}->{total_time} += $previous_attempts*20*60;
		if ($psolved==1) { $Team{$uid}->{first_time} = $ptime }
		$Team{$uid}->{"problem_$prob td"} = '';
		if (time - $starttime > 86400)
		{ $Team{$uid}->{"problem_$prob td"}.= sprintf("%04d-%02d-%02d ",$year,$mon,$day) }
		$Team{$uid}->{"problem_$prob td"}.= sprintf("%02d:%02d:%02d",$hour,$min,$sec);
		if (ref($ScoreEval) eq 'CODE') {
		    $Team{$uid}->{score} = &$ScoreEval($Team{$uid}, $prob); }
	    }
	} elsif ($status =~ /\bnot judged yet\b/) {
	    $Team{$uid}->{"problem_$prob td not judged"} = 1;
	} elsif ($status =~ /^\s*judging\b/) {
	    $Team{$uid}->{"problem_$prob td judging"} = 1;
	}
    }

    my $cmp = sub {
	my $a=shift; my $b=shift; my $ta = $Team{$a}; my $tb = $Team{$b};
	if ($ta->{problems_solved} < $tb->{problems_solved}) { return 1 }
	if ($ta->{problems_solved} > $tb->{problems_solved}) { return -1 }
	if ($ta->{total_time} > $tb->{total_time}) { return 1 }
	if ($ta->{total_time} < $tb->{total_time}) { return -1 }
	if ($ta->{total_att} < $tb->{total_att}) { return 1 }
	if ($ta->{total_att} > $tb->{total_att}) { return -1 }
	return $ta->{displayid} cmp $tb->{displayid};
    };
		    
    my $rank=0; @TeamsRanked = ();
    for my $team (sort { &$cmp($a,$b) } keys(%Team)) {
	next unless $Team{$team}->{competitor};
	#next unless $Team{$team}->{total_att} > 0;
	++$rank;
	$Team{$team}->{rank} = $rank;
	push @TeamsRanked, $team;
	if (ref($ScoreEval) eq 'CODE') {
	    if ($Team{$team}->{score} eq '') { $Team{$team}->{score} = 0; }
	}
    }

    for my $k (keys(%Team)) {
	if (!exists($Team{$k}->{displayid})) { $Team{$k}->{displayid} = $k }
	# Choosing displayid to show
	$Team{$k}->{displayidshow} = $Team{$k}->{displayid};
	if ($Team{$k}->{problems_solved} > 2 and
	    exists($Team{$k}->{displayid1})) {
	    $Team{$k}->{displayidshow} = $Team{$k}->{displayid1}; }
    }
    
}

sub soltime2str {
    use POSIX;
    my $sec = shift; $sec = 0 if $sec eq '';
    my $min;   if ($sec >= 60) { $min = POSIX::floor($sec/60); $sec %= 60; }
    my $hours; if ($min >= 60) { $hours = POSIX::floor($min/60); $min %= 60; }
    my $days;  if ($hours >= 24) { $days = POSIX::floor($hours/24); $hours %= 24; }
    my $totaltime =
	($days>1 ? "${days}days " : ($days>0 ? "${days}day " : ''));
    $totaltime.= ($hours>0 ? "${hours}:" : '');
    $totaltime.= sprintf("%02d:%02ds",$min, $sec);
    return $totaltime;
}

sub finish_page {
    print $Page_final_part;
    if ($Error ne '') { &send_email_error }
    &store_log if $LogReport ne '';
    exit;
}

sub htmlquote($) {
    my $c = shift;
    return Text::Starfish::htmlquote($c);
}

########################################################################
#:section User Role-Based Access Control and Session Management

sub login_email_or_dpcid {
    my $email = shift; my $password = shift;
    $email = lc $email; $email =~ s/\(.*\)//g; $email =~ s/^\s+//; $email =~ s/\s+$//;
    if ($email eq '') { $Error='No e-mail provided.'; return; }
    if ($email !~ /@/) {
	my $e = &get_user_for_kv('dpcid', $email);
	if ($e ne '' && exists($e->{email})) { $email = lc $e->{email} }
	$email =~ s/\(.*\)//g; $email =~ s/^\s+//; $email =~ s/\s+$//;
    }
    if (!emailcheckok($email)) { $Error='Invalid e-mail address provided.'; return; }
    if ($password eq '') { $Error='No password provided.'; return; }
    my $password1 = &find_password($email);
    if ($password1 eq '') {
	$Error='Invalid userid or email.';
	$ErrorInternal="Could not find password for email: <$email>\n";
	return;
    }
    if ($password ne $password1) {
	$Error='Invalid password.';
	$ErrorInternal.="User with email ($email) provided incorrect password.\n";
	# Insecure to pass this: "Provided ($password) instead of ($password1).";
	return;
    }
    $LogReport.="User $UserEmail logged in.";
    &set_new_session_for_email($email);
}


sub change_user_role_to {
    my $newrole = shift;
    if (!( grep {$_ eq $newrole} @UserRoles)) {
	$Error.= 'Invalid new role.';
	$ErrorInternal.="Invalid new role ($newrole) for user ($UserId).\n";
	return;
    }
    return if $SessionId eq '';
    $UserRole = $newrole;
    putfile("db/sessions.d/$SessionId/session.info",
	    "SessionId:$SessionId\nTicket:$Ticket\nemail:$UserEmail\n".
	    "UserRole:$UserRole\n");

}

# Moving to DPC::print_header
sub print_header { return DPC::print_header(@_) }
sub DPC::print_header {
    if ($SessionId eq '') { print header } else
    { print header(-cookie=>cookie(-name=>'DPC', -value=>"$SessionId $Ticket")) }
}

# Moving to DPC::analyze_cookie
sub analyze_cookie { return DPC::analyze_cookie(@_) }
sub DPC::analyze_cookie {
    my $c = cookie(-name=>'DPC'); # sessionid and ticket
    if ($c eq '') { $SessionId = $Ticket = ''; return; }
    ($SessionId, $Ticket) = split(/\s+/, $c);
    if ($SessionId !~ /^\w+$/ or $Ticket !~ /^\w+$/)
    { $SessionId = $Ticket = ''; return; }

    # check validity of session and set user variables
    my $sessioninfofile = "db/sessions.d/$SessionId/session.info";
    if (!-f $sessioninfofile) { $SessionId = $Ticket = ''; return; }
    my $se = &read_db_record("file=$sessioninfofile");
    if (!ref($se) or $Ticket ne $se->{'Ticket'}) { $SessionId = $Ticket = ''; return; }
    my $u;
    if ($se->{'dpcid'} ne '')
    { $u = DPC::get_user_for_kv_if_unique('dpcid', $se->{'dpcid'}) }
    if ($u eq '' and $se->{'email'} ne '')
    { $u = DPC::get_user_for_kv_if_unique('email', $se->{'email'}) }
    if ($u eq '' or $Error ne '') {
	$ErrorInternal.= "E-700: Could not locate user by dpcid=(".
	    $se->{'dpcid'}.") or email(".$se->{'email'}.")\n";
	$SessionId = $Ticket = ''; return;
    }
    $UserRole = $se->{'UserRole'};
    &set_user_vars($u);
}

# Moving to DPC::get_user_for_email
sub get_user_for_email { return DPC::get_user_for_email(@_) }
sub DPC::get_user_for_email {
    my $email = shift;
    if (!-f 'db/users.db')
    { $Error.= 'File db/users.db does not exist (ERR-DPC.pm-288).'; return; }
    my @db = @{ &read_db('file=db/users.db') };
    # check uniqueness of dpcid
    my %h;
    for my $r (@db) {
	my $userid = $r->{'dpcid'};
	if ($r->{'dpcid'} eq '') { $r->{'dpcid'} = lc $r->{'firstname'} }
	if ($r->{'dpcid'} eq '') { $r->{'dpcid'} = 'dpc' }
	if (exists($h{$r->{'dpcid'}})) {
	    my $count = 1; my $id = $r->{'dpcid'};
	    while (exists($h{ "$id-$count" })) { ++$count }
	    $r->{'dpcid'} = "$id-$count";
	}
	if ($userid ne $r->{'dpcid'}) { &update_db("file=db/users.db", \@db) }
	$h{$r->{'dpcid'}} = 1;
    }
    for my $r (@db) { if ($email eq lc $r->{email}) { return $r } }
    return '';
}

sub get_user_for_kv {
    my $key = shift;
    my $val = shift;
    return '' if $key eq '' or $val eq '';
    my $f = shift; $f = 'db/users.db' if $f eq '';
    if (!-f $f)
    { $Error.= "File $f does not exist (ERR: DPC-752)."; return; }
    my @db = @{ &read_db("file=$f") };
    for my $r (@db)
    { if (exists($r->{$key}) && $r->{$key} eq $val) { return $r } }
    return '';
}

sub DPC::get_user_for_kv_if_unique {
    my $key = shift; my $val = shift;
    return '' if $key eq '' or $val eq '';
    my $f = shift; $f = 'db/users.db' if $f eq '';
    if (!-f $f)
    { $Error.= "File $f does not exist (ERR-744)."; return; }
    my @db = @{ &read_db("file=$f") };
    my $found;
    for my $r (@db) {
	if (exists($r->{$key}) && $r->{$key} eq $val) {
	    return '' if $found ne '';
	    $found = $r;
	} }
    return $found;
}

sub set_random_displayids {
  return if (!-f 'db/users.db');
  my @db = @{ &read_db('file=db/users.db') };
  # check existence of all displayids
  my $flag = '';
  for my $r (@db) { if (!exists($r->{displayid})) { $flag=1; last; } }
  return if !$flag;
  return unless lock_mkdir('db/users.db');
  my $counter;
  @db = @{ &read_db('file=db/users.db') }; my %h=();
  for my $r (@db) {
    if (exists($r->{displayid}) && $r->{displayid} ne '') {
      $h{ $r->{displayid} } = 1; next; }
    for( ++$counter; exists( $h{ sprintf("s%02d", $counter) } ); ++$counter) {}
    my $d = sprintf("s%02d", $counter); $r->{displayid} = $d; $h{$d} = 1;
  }
  &update_db("file=db/users.db", \@db);
  unlock_mkdir('db/users.db');
}

sub set_random_sitecodes {
  return if (!-f 'db/users.db');
  my @db = @{ &read_db('file=db/users.db') };
  # check existence of all sitecodes
  my $flag = '';
  for my $r (@db) { if (!exists($r->{sitecode})) { $flag=1; last; } }
  return if !$flag;
  return unless lock_mkdir('db/users.db');
  @db = @{ &read_db('file=db/users.db') };
  for my $r (@db) {
    if (!exists($r->{sitecode}) || $r->{sitecode} eq '')
    { $r->{sitecode} = &random_numbers(4) }
  }
  &update_db("file=db/users.db", \@db);
  unlock_mkdir('db/users.db');
}

sub login {
    my $email = shift; my $password = shift;
    $email = lc $email; $email =~ s/\(.*\)//g; $email =~ s/^\s+//; $email =~ s/\s+$//;
    if ($email eq '') { $Error='No e-mail provided.'; return; }
    if (!emailcheckok($email)) { $Error='Invalid e-mail address provided.'; return; }
    if ($password eq '') { $Error='No password provided.'; return; }
    my $password1 = &find_password($email);
    if ($password1 eq '') {
	$Error='Invalid userid or email.';
	$ErrorInternal="Could not find password for email: <$email>\n";
	return;
    }
    if ($password ne $password1) {
	$Error='Invalid password.';
	$ErrorInternal.="User with email ($email) provided incorrect password.\n";
	# Insecure to pass this: "Provided ($password) instead of ($password1).";
	return;
    }
    $LogReport.="User $UserEmail logged in.";
    &set_new_session_for_email($email);
}

sub set_new_session_for_email {
    my $email = shift; $email = lc $email;
    if ($email eq '') { $Error='No e-mail provided.'; return; }
    if (!emailcheckok($email)) { $Error='Invalid e-mail address provided.'; return; }
    my $u = &get_user_for_email($email);
    if ($u eq '') {
	$Error.='User not found. (Unexpected error, please contact administrator.)';
	$ErrorInternal.="User not found for email: <$email>";
	return '';
    }
    $LoginEmail = $email;
    DPC::set_new_session($u);
    return $SessionId;
}

sub DPC::set_new_session_for_kv {
    my $key=shift; my $val=shift;
    my $u = &get_user_for_kv($key, $val);
    if ($u eq '') {
	$Error.='E-832: User not found. '.
	    '(Unexpected error, please contact administrator.)';
	$ErrorInternal.="DPC-833:User not found for key=($key) val=($val)";
	return '';
    }
    return DPC::set_new_session($u);
}

sub DPC::set_new_session {
    my $u = shift; # user hash
    my $email = $LoginEmail;
    $email = $u->{'email'} if $email eq '';

    mkdir('db', 0700) or croak unless -d 'db';
    mkdir('db/sessions.d', 0700) or croak unless -d 'db/sessions.d';

    my $sessionid; $^T =~ /\d{6}$/; $sessionid.= "t$&";
    my $s1;
    if ($u->{dpcid} ne '') { $s1 = "d".$u->{dpcid} }
    else { $s1 = "e$email" }
    $s1.= "______"; $s1 =~ /.*?(\w).*?(\w).*?(\w).*?(\w).*?(\w).*?(\w)/;
    $s1 = "$1$2$3$4$5$6"; $sessionid.=$s1;
    my $cm = 0700;
    if (defined($DPC::Chmod{'sessiond'})) {
	$cm = $DPC::Chmod{'sessiond'}; umask ~$cm; }
    if (! mkdir("db/sessions.d/$sessionid", $cm)) {
	my $cnt=1;
	for(;$cnt<100 and
	    !mkdir("db/sessions.d/${sessionid}_$cnt", $cm); ++$cnt) {}
	croak "Cannot create sessions!" if $cnt == 100;
	$sessionid = "${sessionid}_$cnt";
    }
    $SessionId = $sessionid; $Ticket = &random_name;
    my $sessfile = "db/sessions.d/$SessionId/session.info";
    putfile($sessfile,
	    "SessionId:$SessionId\nTicket:$Ticket\ndpcid:$u->{dpcid}\n".
	    "email:$email\n");
    if (defined($DPC::Chgrp{'sessiond'})) {
	my $gid = getgrnam($DPC::Chgrp{'sessiond'});
	chown $>, $gid, "db/sessions.d/$SessionId", $sessfile; }
    
    $UserEmail = $email;
    DPC::set_user_vars($u);
    $DPC::SessionId = $main::SessionId;
    return $main::SessionId;
}

# Moving to DPC::logout
sub logout { return DPC::logout(@_) }
sub DPC::logout {
    $Cookie = cookie(-name=>'DPC', -value=>'', -expires=>"now");
    my $dir = "db/sessions.d"; my $dir1=$dir; my $dir2="db/sessions-old.d";
    my $e; -d $dir2 or $e=1;
    if ($e) { $e='' if mkdir($dir2, 0700) }
    if ($e) { rename("$dir/$SessionId","$dir1/$SessionId-loggedout") }
    else    { rename("$dir/$SessionId","$dir2/$SessionId-loggedout") }
    $LogReport.="User logged out: $UserFirstName $UserLastName <$UserEmail>\n";
    $SessionId = $Ticket = $UserEmail = '';
    DPC::set_user_vars_empty;
}

# Moving to DPC::set_user_vars_empty
sub set_user_vars_empty { return DPC::set_user_vars_empty(@_); }
sub DPC::set_user_vars_empty {
    $User = $UserId = $UserEmail = '';
    $UserFirstName = $UserLastName = $UserRole = '';
}

# Moving to DPC::set_user_vars
sub set_user_vars { return DPC::set_user_vars(@_); }
# Allows that $UserEmail and UserRole are already set
sub DPC::set_user_vars {
    my $u = shift;
    $User = $u; $UserId = $u->{'dpcid'};
    if ($UserEmail eq '') { $UserEmail = $u->{'email'} }
    $UserFirstName = $u->{firstname}; $UserLastName = $u->{lastname};
    @UserRoles = split(/\s*,\s*/,$u->{roles});
    if ($UserRole eq '' || !(grep {$_ eq $UserRole} @UserRoles))
    { $UserRole = $UserRoles[0] }
}

########################################################################
#:section Email and Log Functionality

# Moving to DPC::store_log
sub store_log { return DPC::store_log(@_); }
sub DPC::store_log {
    package main;
    return unless LogReport ne '';
    my $emailLogReport = "CompetitionId: $CompetitionId\n".
	"PWD: ".`pwd`."\n$LogReport";
    &send_email_to_admin('Log entry', $emailLogReport);
}

sub DPC::save_to_log {
  my $m = shift;
  open(my $fh, ">db/log") or croak("Cannot open >db/log: $!");
  print $fh $m; close($fh);
}

sub send_email_error { return DPC::send_email_error(@_); }
sub DPC::send_email_error {
  package main;
  my $subject = "Subject: DPC Error Report";
  my $msg = "Error: $Error\nError Internal:$ErrorInternal\n";
  my $email = "From: $DPC_email_from\nTo: $DPC_email_bcc\n$subject\n\n$msg";
  if (open(my $sendm, "|/usr/lib/sendmail -ti")) {
    print $sendm $email; close($sendm);
    DPC::save_to_log("EMAIL SENT:\n$email");
  } else {
    DPC::save_to_log("COULD NOT SEND EMAIL 1102-ERR:\n$email"); }
}

#&send_password_reminder(email=>$email, password=>$password);
sub send_password_reminder {
    my %args = @_;
    my $email = $args{email};
    my $password = $args{password};
    &send_email_to($email, "Subject: $CompetitionId Password Reminder",
		   "Hi,\n\n".
		   "Your email and password for the $CompetitionId site is:\n\n".
		   "Email: $email\nPassword: $password\n\n".
		   "You can log in at:\n\n".
		   "$HttpsBaseLink/login.cgi\n\n\n".
		   "Best regards,\nDPC Team\n");
}

sub send_email_password_gen {
    my $email = shift; my $email=lc $email;
    if ($email eq '') { $Error='No e-mail provided to send password.'; return; }
    if (!emailcheckok($email)) { $Error='Invalid e-mail address provided.'; return; }

    if (!-f 'db/users.db') { $Error = 'Please contact administrator (login-281).'; return; }
    my @db = @{ &read_db('file=db/users.db') };
    my $found = '';
    for my $r (@db) { if ($email eq lc $r->{email}) { $found = 1; last; } }
    
    if (!$found) {
	$Error = 'Your e-mail has not been registered.';
	$ErrorInternal.= "E-mail ($email) not registered.";
	return;
    }
    my $password = &find_password_or_generate($email);
    if ($password !~ /^\S+$/) { croak("Internal error with retrieved password.") }

    &send_email_to($email, "Subject: $CompetitionId Password Reminder",
		   "Hi,\n\n".
		   "Your email and password for the $CompetitionId site is:\n\n".
		   "Email: $email\nPassword: $password\n\n".
		   "You can log in at:\n\n".
		   "$HttpsBaseLink/login.cgi\n\n\n".
		   "Best regards,\n$CompetitionId Team\n");
    return;
}

# used in login.cgi
sub send_email_reminder {
    my $email = shift; my $email=lc $email;
    &send_email_password_gen($email);

    &myprint("<p>Your password has been sent to the email address $email.\n");
    &myprint("<p>You can return to the <a href=\"index.cgi\">main page</a>, ".
	"or to the <a href=\"login.cgi\">login page</a>.\n");
    return;

    $Error = 'So far so good.'; return;

    my $userhash =  md5_base64(lc $email); $userhash=~s/[^\w]/_/g;
    
    if ($DBDirRegistrations ne '' && !-f "$DBDirRegistrations/$userhash.reg") {
	$Error = 'Your e-mail has not been registered.';
	return;
    }
    $Error = 'Development in progress.';
}

# new function added as a copy
sub dpc_send_email_reminder {
    my $email = shift; my $email=lc $email;
    &send_email_password_gen($email);

    &myprint("<p>Your password has been sent to the email address $email.\n");
    &myprint("<p>You can return to the <a href=\"index.cgi\">main page</a>, ".
	"or to the <a href=\"login.cgi\">login page</a>.\n");
    return;

    $Error = 'So far so good.'; return;

    my $userhash =  md5_base64(lc $email); $userhash=~s/[^\w]/_/g;
    
    if ($DBDirRegistrations ne '' && !-f "$DBDirRegistrations/$userhash.reg") {
	$Error = 'Your e-mail has not been registered.';
	return;
    }
    $Error = 'Development in progress.';
}

sub send_email_welcome {
    my $email = shift; my $email=lc $email;
    if ($email eq '') { $Error='No e-mail provided to send password.'; return; }
    if (!emailcheckok($email)) { $Error='Invalid e-mail address provided.'; return; }

    if (!-f 'db/users.db') { $Error = 'Please contact administrator (ERR-334).'; return; }
    my @db = @{ &read_db('file=db/users.db') };
    my $u='';
    for my $r (@db) { if ($email eq lc $r->{email}) { $u=$r; last; } }
    
    if ($u eq '') {
	$Error = 'Your e-mail has not been registered.';
	$ErrorInternal.= "E-mail ($email) not registered.";
	return;
    }

    if (!-r 'email/msg.welcome') { $Error = 'Please contact administrator (ERR-345).'; return; }
    my $welcomeEmail = getfile('email/msg.welcome');
    $welcomeEmail =~ s/\$FirstName\b/$u->{firstname}/g;
    my $subjectLine = 'Subject: Welcome';
    if ($welcomeEmail =~ /^(Subject:.*)\n+/) { $subjectLine = $1; $welcomeEmail = $'; }
    &send_email_to($email, $subjectLine, $welcomeEmail);
    return;
}

sub send_email_to_admin { return DPC::send_email_to_admin(@_); }
sub DPC::send_email_to_admin {
  package main;
  my $subject = shift; my $msg = shift;
  $subject =~ s/\s+/ /g;
  $subject = "Subject: [DPC-Adm:$CompetitionId] $subject";
  my $email = "From: $DPC_email_from\nTo: $DPC_email_bcc\n$subject\n\n$msg";
  if (open(my $sendm, "|/usr/lib/sendmail -ti")) {
    print $sendm $email; close($sendm);
    DPC::save_to_log("EMAIL SENT:\n$email");
  } else {
    DPC::save_to_log("COULD NOT SEND EMAIL 1243-ERR:\n$email"); }
}

# Using:
# $DPC_email_from = '"Dalhousie Programming Contest for High School Students" <dpc+h@cs.dal.ca>';
# $DPC_email_bcc  = '"DPC copy" <dpc+bcc@cs.dal.ca>';
sub send_email_to {
    my $email = shift; croak unless &emailcheckok($email);
    my $subject = shift;
    if ($subject !~ /^Subject: /) { croak }
    my $msg = shift;
    local *S; open(S,"|/usr/lib/sendmail -ti") or croak("Cannot access sendmail.");
    print S "From: $DPC_email_from\nTo: <$email>\nBcc: $DPC_email_bcc\n$subject\n\n";
    print S $msg; close(S);
}


########################################################################
#:section Data read and write, DB functionality
# &update_db("file=db", \@a); updates the file or returns the string copy of contents
# keeps the order of records and fields if possible
sub update_db {
    my $arg = shift; my $db=shift; my $file=''; local *F;
    if ($arg =~ /^file=/) {
	$file = $'; die "file=''!?" if $file eq '';
	open(F, "+<$file") or croak "cannot open $file:$!"; &lock_ex(*F);
	$arg = join('', <F>);
    }

    my $arg_save = $arg; my $dbi = 0; my $argcopy = '';
    while ($arg) {
	# allow comments and space betwen records
	if ($arg =~ /^(\s*\n|[ \t]*#.*\n)*/) { $argcopy.=$&; $arg = $'; }
	my $record;
        if ($arg =~ /\n(\n+)/) { $record = "$`\n"; $arg = $1.$'; }
        else { $record = $arg; $arg = ''; }
        if ($dbi > $#{$db}) { last }
        my $r = {}; my %savedkeys = ();
	while ($record) {
	    my $avpair = '';
	    if ($record =~ /^.*/) { $avpair = $& }
	    while ($record =~ /^(.*)(\\\n|\n[ \t]+)(.*)/)
	    { $record = "$1 $3$'"; $avpair.= $2.$3; }
            $record =~ /^([^\n:]*):(.*)\n/ or die;
            my $k = $1; my $v = $2; $record = $';
	    $avpair .= "\n";
	    if (exists($r->{$k})) {
                my $c = 0;
                while (exists($r->{"$k-$c"})) { ++$c }
                $k = "$k-$c";
            }
            $r->{$k} = $v;
	    if (exists($db->[$dbi]->{$k}) && $db->[$dbi]->{$k} eq $v)
	    { $argcopy .= $avpair }
	    elsif (exists($db->[$dbi]->{$k})) {
	        my $newv = $db->[$dbi]->{$k}; $newv =~ s/\s/ /g; #to be improved
		$argcopy .= "$k:$newv\n";
            } # else skip it
	    $savedkeys{$k} = 1;
        }
	for my $k (keys %{ $db->[$dbi] }) {
	    if (!exists($savedkeys{$k})) {
	        my $newv = $db->[$dbi]->{$k}; $newv =~ s/\s/ /g; #to be improved
		$argcopy .= "$k:$newv\n";
	    }
	}
        ++$dbi;
    }
    if ($file ne '') {
        if ($argcopy ne $arg_save) {
	    putfile("$file.bak", $arg_save);
	    seek(F,0,0); print F $argcopy; close(F);
	}
	return;
    } else { return $argcopy }
} # End of sub update_db

sub read_db {
  my $arg = shift;
  if ($arg =~ /^file=/) {
      my $f = $'; local *F; open(F, $f) or die "cannot open $f:$!";
      $arg = join('', <F>); close(F);
  }

  my $db = [];
  while ($arg) {
      # allow comments between records
      while ($arg =~ /^\s*#/)
      { $arg =~ s/^\s*(#.*\s*)*// }
      if ($arg eq '') { last }
      my $record;
      if ($arg =~ /\n\n+/) { $record = "$`\n"; $arg = $'; }
      else { $record = $arg; $arg = ''; }
      my $r = {};
      while ($record) {
        while ($record =~ /^(.*)(\\\n|\n[ \t]+)(.*)/)
	{ $record = "$1 $3$'" }
        $record =~ /^([^\n:]*):(.*)\n/ or die; # confess, die
        my $k = $1; my $v = $2; $record = $';
        if (exists($r->{$k})) {
          my $c = 0;
          while (exists($r->{"$k-$c"})) { ++$c }
          $k = "$k-$c";
        }
        $r->{$k} = $v;
      }
      push @{ $db }, $r;
  }
  return $db;
}

# Get the source record for key and value:
# $text = &get_record_kv($k,$v,$file);
# !!!not finished
sub get_record_kv {
  my $key = shift; my $val = shift; my $file = shift;
  return '' if $key eq '' or $val eq '' or $file eq '' or !-f $file;

  my @db = @{ &read_db("file=$f") };
    for my $r (@db)
    { if (exists($r->{$key}) && $r->{$key} eq $val) { return $r } }
    return '';
}

# Read one record and return ref to hash
sub read_db_record {
    my $arg = shift;
    if ($arg =~ /^file=/) {
	my $f = $'; local *F; open(F, $f) or die "cannot open $f:$!";
	$arg = join('', <F>); close(F);
    }

    while ($arg =~ s/^(\s*|\s*#.*)\n//) {} # allow comments before record
    my $record;
    if ($arg =~ /\n\n+/) { $record = "$`\n"; $arg = $'; }
    else { $record = $arg; $arg = ''; }
    my $r = {};
    while ($record) {
        while ($record =~ /^(.*)(\\\n|\n[ \t]+)(.*)/)
	{ $record = "$1 $3$'" }
        $record =~ /^([^\n:]*):(.*)\n/ or die;
        my $k = $1; my $v = $2; $record = $';
        if (exists($r->{$k})) {
	    my $c = 0;
	    while (exists($r->{"$k-$c"})) { ++$c }
	    $k = "$k-$c";
        }
        $r->{$k} = $v;
    }
  return $r;
}

########################################################################
#:section Low-lever read/write routines

sub getfile($) {
    my $f = shift;
    local *F; open(F, "<$f") or die "getfile:cannot open $f:$!";
    &lock_sh(*F) or croak; my @r = <F>; close(F);
    return wantarray ? @r : join ('', @r);
}

sub DPC::getfile_limit($) {
    my $f = shift; my $sz = 0;
    local *F; open(F, "<$f") or die "getfile:cannot open $f:$!";
    my @r;
    while (<F>) {
	push @r, $_; $sz += length($_); last if $sz > 100000;
    }
    close(F);
    return wantarray ? @r : join ('', @r);
}

# The OS based locking (described above) sometimes does not work.  One
# interesting way to simulate it using the mkdir system call, which is
# supposed to be atomic in any OS (e.g., even DOS).  I saw this idea
# in the documentation of procmail or smartlist (same author, I believe).
#
# Exlusive locking using mkdir
# lock_mkdir($fname); # return 1=success ''=fail
sub lock_mkdir {
  my $fname = shift; my $lockd = "$fname.lock";
  my $locked = ''; # flag
  # First, hopefully most usual case
  if (!-e $lockd && ($locked = mkdir($lockd,0700))) { return $locked }
  my $tryfor = 3; #sec
  for (my $i=0; !$locked and $i<2*$tryfor; ++$i) {
    !-e $lockd && ($locked = mkdir($lockd,0700));
    if ($locked) { return $locked }
    select(undef,undef,undef,0.5); # wait for 0.5 sec
  }
  return $locked;
}

# Unlock using mkdir
# unlock_mkdir($fname); # return 1=success ''=fail or no lock
sub unlock_mkdir {
  my $fname = shift; my $lockd = "$fname.lock";
  if (!-e $lockd) { return '' }
  if (-d $lockd) {  return rmdir($lockd) }
  if (-f $lockd or -l $lockd) { unlink($lockd) }
  return '';
}

########################################################################
#:section Low-level String Functions (random, encodings, etc.)

sub random_name {
    my $n = shift; $n = 8 unless $n > 0;
    my @chars = (0..9, 'a'..'z', 'A'..'Z');
    return join('', map { $chars[rand($#chars+1)] } (1..$n));
}
sub random_letters {
    my $n = shift; $n = 8 unless $n > 0;
    my @chars = ('a'..'k', 'm' .. 'z', 'A'..'N', 'P'..'Z');
    return join('', map { $chars[rand($#chars+1)] } (1..$n));
}
sub random_numbers {
    my $n = shift; $n = 8 unless $n > 0;
    my @chars = (2..9);
    return join('', map { $chars[rand($#chars+1)] } (1..$n));
}
sub random_password {
    my $n = shift; $n = 8 unless $n > 0;
    my @chars = (2..9, 'a'..'k', 'm'..'z', 'A'..'N', 'P'..'Z',
                 qw(, . / ? ; : - = + ! @ $ % *) );
    return join('', map { $chars[rand($#chars+1)] } (1..$n));
}
sub encode_w {
    local $_ = shift;
    s/[\Wx]/'x'.uc unpack("H2",$&)/ge;
    return $_;
}
sub decode_w {
    local $_ = shift;
    s/x([0-9A-Fa-f][0-9A-Fa-f])/pack("c",hex($1))/ge;
    return $_;
}

########################################################################
#:section Debug and Development Routines

sub debug { return DPC::debug(@_) }
sub DPC::debug {
    $LogReport.="DEBUG:@_\n";
}

#sub print_hash {
#    my %h = @_; print "<pre>\n";
#    for my $k (sort keys %h) {
#	print "(<b>".&htmlsanitize($k)."</b>) => (".&htmlsanitize($h{$k}).")\n";
#    }
#    print "</pre>\n";
#}

sub print_hash {
    my %h = @_; my @k = sort(keys(%h));
    for my $k (@k) { &print_hash_line($k, $h{$k}) }
}
sub print_hash_line {
    my $k = shift; my $v = shift;
    my $kh = Text::Starfish::htmlquote($k); my $vh = Text::Starfish::htmlquote($v);
    print "<b>$kh:</b> ($vh)<br>\n";
}

sub print_params {
    my @k = param(); @k = sort @k;
    for my $k (@k) { &print_hash_line($k, param($k)) }
}

sub print_environment {
    for my $k (keys %ENV) {
	my $kh = Text::Starfish::htmlquote($k); my $vh = Text::Starfish::htmlquote($ENV{$k});
	print "<b>$kh :</b> $vh<br>\n";
    }
}

#sub printENVandparam {
#print "<pre>\n";for my $k (keys %ENV) { print "ENV $k=($ENV{$k})\n" } print "</pre>\n";
#print "<pre>\n";for my $k (param()) { print "param $k=(".param($k).")\n" } print "</pre>\n";
# }

sub cleanspaces { local $_ = shift; s/^\s+//; s/\s+$//; s/\s+/ /g; return $_; }

########################################################################

1;
