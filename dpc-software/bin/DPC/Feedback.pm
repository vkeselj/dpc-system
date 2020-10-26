# DPC::Feedback. DPC Module for providing feedback on testing.
# Vlado Keselj 2010-2020
use vars (qw($UserId));

sub DPC::Feedback::gen_feedback {
    my %params = @_;
    my $feedback = $params{-feedback};
    my $problem  = $params{-problem}; my $judgec = $params{-judgec};
    my $status = $params{-status}; my $language = $params{-language};
    my $subm = $params{-subm};

    my $lang = $language; $lang = 'C#' if $language eq 'Csharp';

    if ($subm =~
	/(\d\d\d\d)(\d\d)(\d\d)T(\d\d)(\d\d)(\d\d)-(\w+)-(\w+)-(\w+)$/) {
	$feedback.= "userid:$7  ".
	    "time:$4:$5:$6 $1-$2-$3  problem:$8  ".
	    "Programming language:$lang\n";
    }

    $feedback.="\nStatus: $status\n\n";
    if ($status eq 'judging') {
	$feedback.= "Your solution is being judged.\n".
	    "We cannot provide any feedback before judging is finished.\n";
	return $feedback;
    }
    elsif ($status eq 'Compilation Error') {
	my $l = $language; $l = 'C#' if $language eq 'Csharp';
	$feedback.= "Your solution could not be compiled using a ".
	    "$l compiler.\n";
    }
    elsif ($status eq 'Run-time Error') {
	$feedback.= "Execution of your program produced a run-time error.\n";
    }
    elsif ($status =~ /Time Limit Exceeded/) {
	$feedback.="The status \"Time Limit Exceeded\" means that your program\n".
	    "was taking too long time on one of the test cases and had to be\n".
	    "terminated.  It is possible that you implemented a too inefficient\n".
	    "algorithm or the program was stuck in an infinite loop.\n";
    }

    if ($status ne 'Compilation Error' and $status ne 'Solution Accepted!') {
	$feedback.="\nBrief feedback: ";
	if ($judgec eq '') {
	    $feedback.="Your program was not tested yet.\n\n";
	} elsif ($judgec =~ /^Comparing \S+\.out and \S+\.new: Test passed\.$/m) {
	    $feedback.="Your program has passed at least one test.\n\n";
	} else {
	    $feedback.="Your program has not passed even the sample test.\n\n";
	}
    }

    my $reRTE1 = qr/Execution start time:.*\n/;
    my $reRTE2 = qr/Exception in thread \"main\" .*\n/;
    my $reRTE3 = qr/[ \t]+at java\..*\n/;
    my $reRTE4 = qr/[ \t]+at $problem.*\($problem\.java:.*\n/;

    if ($judgec =~ /^$reRTE1($reRTE2)($reRTE3)*?($reRTE4)/m) {
	$feedback.="Runtime error:\n$1\t...\n$3"; }

    my $f1 = $judgec; my $f2;
    local $_ = $judgec;
  L_start:
    s/^\/bin\/cp .*\n//mg;
    s/^(ssh|scp) .*\n//mg;
    s/^\/bin\/rm:.*\n//mg;
    s/^\(\.\/mobile-tester\.pl .*\n//mg;
    s/^Execution (start|end) time:.*\n//mg;
    s/^\n//mg;

    my $sampletest;
    if (/^--- Compilation -+\n/) { $f2.=">>> Compilation:\n"; $_=$'; }
    if (/^(gcc -lm|g\+\+ |javac |python[23]? |mcs ).*\n/) { $f2.=$&; $_=$'; }
    else { goto L_end }
    if (/^Note: $problem\.java uses unchecked.*\n/) { $f2.=$&; $_=$'; }
    if (/^Note: Recompile with .*\n/) { $f2.=$&; $_=$'; }
    if (/^$problem.java:\d+:.*\n/) { $f2.=$&; $_=$'; }
    if (/^$problem\.cs\(.*\n/) { $f2.=$&; $_=$'; }
    if (/^Compilation succeeded .*\n/) { $f2.=$&; $_=$'; }
    if (/^$problem\.(exe|class) -- .*\n/) { $f2.=$&; $_=$'; }
    elsif (/^__pycache__ -- executable created successfully\.\n/) {
      $f2.="Compilation successful.\n"; $_=$'; }
    if (/^--- Testing -+\n/) { $f2.=">>> Testing:\n"; $_=$'; }
  L_start_test:
    $sampletest='';
    if (/^--- Testing with $problem\.in and .*:\n/) {
	$f2.="Sample test: "; $_=$'; $sampletest=1;}
    elsif (/^--- Testing with $problem-(\d+)\.in and .*:\n/) {
	$f2.="Sample test $1: "; $_=$'; $sampletest=1;}
    elsif (/^--- Testing with ${problem}j-(\d+)\.in and .*:\n/) {
	$f2.="Judging test $1: "; $_=$'; }
    else { goto L_end1 }
    if (/^(Time limit exceeded \(over \d+ sec\)!).*\nTime limit.*\n/) {
      $f2.= "$1\n"; $_=$'; }
    if (/^($reRTE2)($reRTE3)*?($reRTE4)/) {
      $f2.= "\n$1\t...\n$3"; $_=$'; }
    if (/^Exec time:.*\n/m) { $_=$' } else {goto L_end}
    if (/^Comparing .*?: (Test (passed|failed).\n)/) {
	$f2.=$1; $_=$'; }
    if (/^diff .*(\n--------+\n[\x00-\xFF]*?\n-----------+\n)/) {
        $_=$'; 
        if ($sampletest) {
          $f2.= "diff (difference between expected and actual output):$1" }
    }
    goto L_start_test;
  L_end1:
    if (/^Recommended Status:.*\n/) { $f2.=$&; $_=$'; }

  L_end:
    if ('' and $UserId eq 'vlado') {
    #if ($UserId eq 'vlado') {
      $f2.=">>>>(only for UserId=$UserId):\n".
           ">>>>>>>>>>>>>>$_";
    }

    $feedback.="\nDetailed judging log:\n".('-'x21)."\n$f2";

    return $feedback;
}

1;
