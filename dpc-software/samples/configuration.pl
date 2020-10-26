#!/usr/bin/perl
# Local competition configuration file: DPC Sample Contest
# Sample configuration file for DPC System

# Different practicum types.  'dpch' is the basic one and should be
# used for now, unless you know what you are doing.
$PracticumType = 'dpch'; # dpc, practicum, dpch1, dpch2
# dpc = DPC practice competition
# practicum = course practicum
# dpch1, dpch2 = DPC/H phrase 1 and phase 2

$ScoreboardPublic = ''; # 1 or ''
$RegistrationOpen = ''; # 1 or ''
$SubmissionOpen   = 1; # 1 or ''
$ContestOpen      = 1; # 1 or ''

$CompetitionDate     = '2020-10-03'; # eg: '2012-04-03' used for DPC-YYYY-MM-DD
$CompetitionStartTime= '2020-10-03 10:00:00';
$ProblemsAvailableAt = '2020-10-03 10:00:00';

$CompetitionEndTime  = '2020-12-03 10:00:00';
$AllowViewAfterEndTime = 1;  # allow login, view problems and scoreboard,
                             # but not submissions

$CompetitionId='DPC-Sample-Contest';
# Some examples:
#$CompetitionId='ICPC-NA-ACPC-2019-Open';
#$CompetitionId='ICPC-NA-ACPC-2019';
#$CompetitionId='DalCode-2020-1';
#$CompetitionId='DPC-H-2019-1';
#$CompetitionId = "DPC-$CompetitionDate"; # eg: 'DPC-$H-2013-1' "DPC-$CompetitionDate"
#$CompetitionId = "CSCI2132-P4"; # eg: 'DPC-H-2013-1' "DPC-$CompetitionDate"

# $ScoreboardFreezeTime='2011-05-13 13:20:00';

# Enter the base URL link for the contest
$HttpsBaseLink = "https://web.cs.dal.ca/~dpc/$CompetitionDate-sample";

$CompetitionFullTitle   = 'DPC Sample Contest';
$CompetitionHeaderTitle = 'DPC Sample Contest';

$TemplateFile = 'templates/dpc-3.html.sfish';

$DPC_email_from = '"DPC System" <vlado+dpc@dnlp.ca>';
$DPC_email_bcc  = '"DPC copy" <vlado+dpc@dnlp.ca>';

# AuthenticationType should be local.  The other options are not
# open-sourced yet.
# local - use db/password for user passwords
# local, csid, csid-db, csid+local, csid+site csid
# - csid, add if not in db csid+db - csid, but required to be in
# users.db csid+site - CSID password + site code csid,locA - CSID or
# allowed local
$AuthenticationType = 'local';

# Allowed programming languages.  Choose from the following list:
# Java C C++ Python Python2 Python3 C#
#@PLanguages = qw(C);
#@PLanguages = ('Java', 'C', 'C++', 'Python');
#@PLanguages = qw(Java C C++ Python Python2 Python3);
 @PLanguages = qw(Java C C++ Python2 Python3);
#@PLanguages = qw(Java C C++ Python2 Python3 C#);
#@PLanguages = ('Java', 'C', 'C++');
#@PLanguages = ('Java');

# Sandbox account for remote judging:
$RemoteJudgingAccount = 'dpc@sandbox.cs.dal.ca';

$DBDirRegistrations = 'db/registrations.d';
$Feedback = ''; # 1 or '' -- provide feedback on solutions

# Setup if needed, directory and file permissions and group
# ownerships.  These are used for files and directories created by CGI
# scripts.  The suEXEC option of the web server is assumed by default,
# so the default permissions are 0700, and the group is not changed.
# However, if suEXEC is not available, and we have a group that
# includes the userid owning the directory and web server userid, then
# we should set Chmod to 0770 and Chgrp to that group; e.g.:
# $DPC::Chmod{'sessiond'} = 0770; $DPC::Chgrp{'sessiond'} = 'vlado';
# As the last option, we need to make created files all readable,
# which should be done only on a completely trusted system.
# $DPC::Chmod{'sessiond'} = 0770; $DPC::Chgrp{'sessiond'} = 'vlado';

# If ScoreEval defined, the score will be shown on the scoreboard.
# It can be used for evaluating assignments.
# $ScoreEval = sub {
#     my $team = shift;
#     my $probs = $team->{problems_solved};
#     if ($probs < 1) { return 0 }
# 
#     my $ft = $team->{first_time};
#     my $score;
#     if ($ft <= 90*60) { $score = 15 } # for the first solution in first 1.5h
#     else { $score = 13 }
#     if ($probs >= 2) { $score += 9 } # for 2nd solution
#     if ($probs >= 3) { $score += 6 } # for 3rd solution
# 
#     return $score;
# };

1;
