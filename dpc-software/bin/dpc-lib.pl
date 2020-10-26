#!/usr/bin/perl
# DPC Library of Perl functions; last update: 2020-10-18
use POSIX;
use Text::Starfish;

if ($DPC_email_from eq '') { $DPC_email_from = '"DPC System" <vlado+dpc@dnlp.ca>' }
if ($DPC_email_bcc  eq '') { $DPC_email_bcc  = '"DPC copy" <vlado+dpc@dnlp.ca>' }

sub load_template {
    if ($TemplateFile eq '') { $TemplateFile = 'templates/main-t.html.sfish' }
    my $templatefile = $TemplateFile;

    # if ($UserEmail eq 'vlado@cs.dal.ca' and -f 'templates/main-t-test.html.sfish')
    # { $templatefile = 'templates/main-t-test.html.sfish' }

    if (!-r $templatefile)
    { die "ERR-16: Template file $templatefile does not exist." }

    my $template = getinclude('-replace', $templatefile);
    $template =~ /_CONTENT_/ or die;
    $Page_first_part = $`; $Page_final_part = $';
    $Page_first_part =~ s/(--left--(.|\n)*?"$CGI_file">)(.*?)</$1<i>$3<\/i></;
}

sub development_access {
    my $clientIP = $ENV{'REMOTE_ADDR'};
    #if (1 or !grep { $_ eq $clientIP } qw( 129.173.212.183 24.138.21.187 ))
    if (!grep { $_ eq $clientIP } qw( 129.173.212.183 24.138.21.187 ))
    { return '' }
    return 1;
}

sub early_limit_to_testing {
    if (!&development_access) {
	print header; print "<html><body>Page is temporarily disabled due to system changes.\n";
	exit;
    }
}

sub limit_only_to_testing {
    if (!&development_access)
    { &myprint("Page is temporarily disabled due to system changes."); finish_page_and_exit; }
    &myprint("<p><b>(Page is temporarily disabled. This is development access.)</b>\n");
}

# called at cgi start for set-up
sub cgi_start {
    if ($RemoteUser =~ /^dpc9[0-9]/) { $UserIsJudge = 1 } else {$UserIsJudge = ''}
}


sub store_submission {
    my $filename = shift; my $language = shift; my $problem = shift;
    return '' if $filename eq '';
    my $submissiontime = $^T;
    my $timestamp = strftime("%Y%m%dT%H%M%S", localtime($submissiontime));
    my $filenameloc = $filename; $filenameloc =~ s/[\/|<>]/-/g;
    my $filenamehtml = &htmlsanitize($filename);
    if ($filenameloc eq 'META.info') {
	print "<b>Error!? Invalid file name: $filenamehtml</b>\n";
	return '';
    }
    if ($language ne 'C' && $language ne 'C++' && $language ne 'Java') {
	print "<b>Error!? Unknown language (".&htmlsanitize($language).").</b>\n";
	return '';
    }
    if ($language eq 'C++') { $language = 'CPP' }
    if ($problem !~ /^\s*([A-F])/) {
	print "<b>Error!? Invalid problem (".&htmlsanitize($problem).").</b>\n";
	return '';
    }
    $problem = $1;

    if (!-d 'store') { mkdir 'store', 0700 or die "cannot mkdir 'store': $!" }
    if (-d "store/$timestamp")
    {print "<b>Error!? Please try submitting again and report error to the administrator.</b>\n"; return '';}
    elsif ( !mkdir("store/$timestamp-$language-$problem",0700) )
    {print "<b>Error!? Please try submitting again and report error to the administrator.</b>\n"; return '';}
    local *O; if ( !open(O, ">store/$timestamp-$language-$problem/$filenameloc") )
    {print "<b>Error!? cannot store file($!)! Please report error to the administrator.</b>\n"; return'';}
    &lock_ex(*O); my ($bytesread, $buffer, $bytes);
    while ($bytesread = read($filename, $buffer, 1024))
    { print O $buffer; $bytes+=$bytesread; }
    close (O); local *M; open(M, ">store/$timestamp-$language-$problem/META.info") or croak; &lock_ex(*M);
    print M "Timestamp:$timestamp\nLanguage:$language\nProblem:$problem\nStatus:not judged yet\n";
    close(M);
    return 1;
} # end of sub store_submission


sub print_current_results() {

    @ProblemIds = ();
    for my $p (@ProblemsLetterTitle) { $p=~/^[A-Z]\b/ or die; push @ProblemIds, $&; }

    my %solutions = &get_solutions();

    #mktime(sec, min, hour, mday, month, year, wday=0, yday=0, isdst=0);
    #my $starttime = mk

    for my $sol (sort(keys (%solutions))) {
	next unless $sol=~/^(\d\d\d\d)(\d\d)(\d\d)T(\d\d)(\d\d)(\d\d)-(\w+)-(\w+) (\w+)/;
	my ($year,$mon,$day,$hour,$min,$sec,$lang,$prob,$uid) = ($1,$2,$3,$4,$5,$6,$7,$8,$9);
	my $status = $solutions{$sol}->{status};
	if (!exists($Team{$uid})) { $Team{$uid} = { problems_solved => 0 } }
	++$Team{$uid}->{total_att};
	++$Team{$uid}->{"prob_att_$prob"};
	if ($status =~ /\bpass(ed)?\b/i or $status=~ /^\s*correct\s*$/i) {
	    if (!exists($Team{$uid}->{"problem_$prob"})) {
		$Team{$uid}->{"problem_$prob"} = 'solved';
		$Team{$uid}->{"problem_$prob td"} = sprintf("%02d:%02d:%02d",$hour,$min,$sec);
		$Team{$uid}->{problems_solved} += 1;
		$Team{$uid}->{total_time} += 60*(($hour-15)*60+$min)+$sec;
		$Team{$uid}->{rank_key} = sprintf("%03d%06d",
						  $Team{$uid}->{problems_solved},
						  99999-$Team{$uid}->{total_time});
	    }
	}
    }

    print "<TABLE border=\"1\">\n";
    print "<tr><th><strong><u>Rank</u></strong></th><th><strong><u>Name</u></strong></th>".
	"<th><strong><u>Solved</u></strong></th><th><strong><u>Time</u></strong></th>\n";
    for my $prob (@ProblemIds)
    { print "<th>&nbsp;&nbsp;&nbsp;&nbsp;<strong><u>$prob</u></strong>&nbsp;&nbsp;&nbsp;&nbsp;</th>\n" }
    print "<th>Total solv/att</th><th>Comments</th></tr>\n";
	
    my $rank=0;
    for my $team (sort { $Team{$b}->{rank_key} cmp $Team{$a}->{rank_key} } keys(%Team)) {
	next unless $Team{$team}->{total_att} > 0;
	++$rank;
	use POSIX;
	my $min = POSIX::floor($Team{$team}->{total_time} / 60);
	my $sec = $Team{$team}->{total_time} % 60;
	print "<tr><td align=center>$rank</td><td>$team</td>".
	    "<td align=center>$Team{$team}->{problems_solved}</td>".
	    "<td align=center>".(($min+$sec>0)?"$min:$sec":'')."</td>"; #time
	    #"<td align=center>$Team{$team}->{total_time}</td>"; #time
	    for my $prob (@ProblemIds) {
		my $e;
		if (exists($Team{$team}->{"problem_$prob td"}))
		{ $e = $Team{$team}->{"problem_$prob td"} }
		elsif (exists($Team{$team}->{"prob_att_$prob"}))
		{ $e = $Team{$team}->{"prob_att_$prob"}." att" }
		print "<td align=center>$e</td>";
	    }
	print "<td align=center>".$Team{$team}->{problems_solved}." / ".
	    $Team{$team}->{total_att}."</td><td>";
	if ($Team{$team}->{problems_solved} > 0) {
	    my $e = '';
	    foreach my $u (@{ &read_db('file=../htpasswd.db') }) {
		next unless $u->{userid} eq $team;
		$e = $u->{name};
		$e =~ s/(\w)\b.*/$1/;
		last;
	    }
	    print $e;
	}
	print "</tr>\n";
    }

    print "</table>\n";
    &print_all_submissions;
}


sub get_solutions {
    #for cgi:if ($ENV{HOSTNAME} =~ /bluenose/) { $homedir = "/users/cs/dpc" }
    my $dir = "$BaseDir/$CompetitionId";
    my @accounts = @Accounts;
    my %solutions;
    for my $a (@accounts) {
	#print "($dir/$a/store)";
	for (<$dir/$a/store/*>) {
	    #print "($_)";
	    next unless /\/([\w-]+)$/; my $dirlabel=$1;
	    $solutions{"$dirlabel $a"} = { };
	    $solutions{"$dirlabel $a"}->{dir} = $_;
	    if (!-e "$_/META.info") {
		#print STDERR "Warning: $_/META.info does not exist\n";
		next;
	    }
	    my $c = &getfile("$_/META.info");
	    $c =~/^Status:\s*(.*)/m or next; my $status = $1;
	    #print "Status: $status\n";
	    $solutions{"$dirlabel $a"}->{status} = $status;
	    #print "$dirlabel $a status $status<br>\n";
	}
    }
    return %solutions;
}



sub print_your_submissions {
    my @submissions = <store/*>;
    print "<p>Your submissions:<br><table border=1><tr><th>Submission time</th><th>Problem</th><th>Language</th><th>Status</th></tr>\n";
    for my $subm (sort {$b cmp $a} @submissions) {
	next unless $subm=~/^store\/(\d\d\d\d)(\d\d)(\d\d)T(\d\d)(\d\d)(\d\d)-(\w+)-(\w+)/;
	my ($year,$mon,$day,$hour,$min,$sec,$lang,$prob) = ($1,$2,$3,$4,$5,$6,$7,$8);
	my $status = 'not judged yet';
	if (-e "$subm/META.info") {
	    my $c = &getfile("$subm/META.info");
	    if ($c=~/^Status:\s*(.*)/m) { $status = $1; }
	}
	print "<tr><td>$hour:$min:$sec $day-$mon-$year</td><td>Problem $prob</td><td align=center>$lang</td><td>$status</td></tr>\n";
    }
    print "</table>\n";
}

sub wait { my $t=shift; select(undef,undef,undef,$t); }

#eg: &deliver_pdf("A.pdf", "../some/dir/Abc.pdf");
sub deliver_ps {
    my $fname=shift; my $file = shift; $fname =~ s/[^A-Za-z0-9.-]/x/g;
    print header(-type=>'application/postscript',
		 -content_disposition=>"attachment; filename=$fname");
    local *F; open(F,$file) or die "cannot open $file:$!";
    while (<F>) { print }; close(F);
    exit(0);
}

sub deliver_pdf {
    my $fname=shift; my $file = shift;
    print header(-type=>'application/pdf', -content_disposition=>"attachment; filename=$fname");
    local *F; open(F,$file) or die "cannot open $file:$!";
    while (<F>) { print }; close(F);
    exit(0);
}

#eg: &deliver_text("A.txt", "../some/dir/Abc.txt");
sub deliver_text {
    my $fname=shift; my $file = shift; my $hc=shift;
    #print header(-type=>'text/plain', -content_disposition=>"attachment; filename=$fname");
    print header(-type=>'text/plain'); # seems better for not opening with an app
    local *F; open(F,$file) or die "cannot open $file:$!";
    if ($hc ne '') { print $hc }
    while (<F>) { print }; close(F);
    exit(0);
}

########################################################################
# kw:lock Lock subroutines

# shared lock with time out
sub lock_sh {
    my $h = shift; # handle
    my $locked = ''; # flag
    return 1; # locking does not seem to work
    for (my $i=0; !$locked and $i<20; ++$i) { # try for 2sec
	# Lock flags: 1=SH 2=EX 4=NB 8=UB
	$locked = eval('flock($h, 5)');
	if ($@) { return ''; } # error
	select(undef,undef,undef,0.1); # wait for 0.1 sec
    }
    return $locked;
}

sub lock_ex {
    my $h = shift; # handle
    my $locked = ''; # flag
    return 1; # locking does not seem to work
    for (my $i=0; !$locked and $i<20; ++$i) { # try for 2sec
	# Lock flags: 1=SH 2=EX 4=NB 8=UB
	$locked = eval('flock($h, 6)');
	if ($locked) { return $locked }
	if ($@) { return ''; } # error
	select(undef,undef,undef,0.1); # wait for 0.1 sec
    }
    return $locked;
}

sub unlock {
    my $h = shift; # handle
    # Lock flags: 1=SH 2=EX 4=NB 8=UB
    my $unlocked = eval('flock($h, 8)');
    if ($@) { return ''; } # error
    return $unlocked;
}

# Exlusive locking using mkdir
# lock_mkdir($fname); # return 1=success ''=fail
sub lock_mkdir {
    my $fname = shift; my $lockd = "$fname.lock";
    # First, hopefully most usual case
    if (!-e $lockd && ($locked = mkdir($lockd,0700))) { return $locked }
    my $tryfor=10; #sec
    my $locked = ''; # flag
    for (my $i=0; !$locked and $i<2*$tryfor; ++$i) {
	print "$me:Trying lock...\n";
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

sub create_file_if_no_file {
    my $filename = shift;
    return 1 if -f $filename;
    local *F; open(F, ">>$filename") or croak $!; close(F);
    chmod 0600, $filename;
}

# Should be changed to something more safe.  Used to pass account id
# when RemoteUser does not work.  It does not work for some reason
# when using <Limit GET POST> (Apache bug with old version??).
sub encode_cookie { return $_[0] }
sub decode_cookie { return $_[0] }

sub htmlsanitize {
    my $r = shift;
    s/&/&amp;/g; s/</&lt;/g; s/>/&gt;/g;
    return $r;
}

sub emailcheckok {
    my $email = shift;
    if ($email =~
	/^[a-zA-Z][\w\.+-]*[a-zA-Z0-9+-]@[a-zA-Z0-9][\w\.-]*[a-zA-Z0-9]\.[a-zA-Z][a-zA-Z\.]*[a-zA-Z]$/)
    { return 1 }
    return '';
}

sub useridcheckok { my $userid = shift; return 1 if $userid=~/^[a-zA-Z0-9-]+$/; return ''; }

########################################################################
# Session management kw:sessions

sub find_password {
    my $email = shift;
    if (!-f 'db/passwords') { $Error = "Password file is not set up."; return ''; }
    local *PH; open(PH,"<db/passwords") or croak($!);
    while (<PH>) {
	my ($e,$p) = split;
	if ($e eq $email) { close(PH); return $p; }
    }
    close(PH); return '';
}

sub find_password_or_generate {
    my $email = shift;
    my $password = &find_password($email);
    return $password if $password ne '';
    return '' if $Error ne '';

    if (!-f 'db/passwords') { putfile 'db/passwords', ''; chmod 0600, 'db/passwords' }
    local *PH; open(PH,"+<db/passwords") or croak($!);
    seek(PH,0,0); # read from start
    while (<PH>) {
	my ($e,$p) = split;
	if ($e eq $email) { close(PH); return $p; }
    }
    $password = &random_password(5);
    print PH "$email $password\n";
    close(PH); return $password;
}

1;
