# dpc-system - DPC System for Programming Contests and Practicums

**Status:**  The set of files on github is not complete, as it is
 still in process of making the system open source.
 If you are interested in using the system, send me an email.  It may
 speed up making it available here.

The system is based on Perl CGI scripts and assumes the Linux environment
and file system.  It does not use a database system, but instead
writes to plain files and creates directories to save data.

## Installation

1. The system should be downloaded (git clone is an option) in a
directory accessible to the web server.  It is assumed that this is a
Linux environment with a web server such as Apache or Nginx.  The
system needs to be able to run Perl CGI scripts, and write to certain
directories.  Apache can run Perl CGI scripts, while Nginx needs
additional software, such as FastCGI.  The suEXEC option is the
preferable way of running the scripts, since they would have the
effective userid of the owner of the scripts, so all data could be
protected from other users of the system, and this means an easy way
of setting file permissions since only the owner file permissions
should be set.  If suEXEC is not available, then a good option is to
have the web server userid be in the group which owns the files and
the group permissions should be set appropriatelly.  As the third
option, the files would be all-readable and some all-writable, which
is okay only in a one-user system or where all users can be trusted.

The system can be cloned in a web server accessible directory such as
<code>public_html</code>.  For example, we can do something like:

    cd ~/public_html
    git clone https://github.com/vkeselj/dpc-system.git

and we should have a directory named <code>dpc-system</code> with a
copy of the DPC System.  I use a convention to name the directory as a
date of the competition or practicum (with a possible suffix, such as
<code>-sample</code> or similar), so we can rename it as follows, and
`cd` into it:

    mv dpc-system 2020-10-22-sample
    cd 2020-10-22-sample

2. We cannot access the site immediately because the needed CGI files
are not ready in the main directory.  Instead, they are in the
`dpc-software/samples` directory.  The reason for this is that these
files customizable and we want to allow later `git pull` commands in
order to update the DPC System without overwriting these files.
For this reason, we need to run the following command the first time
the system is created:
    ```
    ./dpc/software/bin/dpc-setup-samples
    ```
This will copy the sample files into the main directory, and set some
permissions of the files.  If the file is not executable, run it using
Perl as:
    ```
    perl dpc/software/bin/dpc-setup-samples
    ```

## ChangeLog

1.2003 2020-10-27
- incomplete package, preparation in progress
- documentation improvements
- added Text/Starfish.pm
- added dpc-software/bin/DPC.pm, dpc-software/bin/dpc-lib.pl,
  dpc-software/bin/DPC/Feedback.pm, dpc-software/samples/configuration.pl
- changed dpc-software/bin/dpc-setup-samples to Perl, skipping
  existing files
- added NAME, ABSTRACT, and VERSION to DPC.pm
- modified dpc-3.html.sfish template to show proper VERSION

1.2002 2020-10-24
- incomplete package, preparation in progress
- documentation improvements
- adding dpc-software/bin/dpc-setup-samples
- adding CGI/AuthRegister.pm (my Perl module on CPAN, but may be used
       directly here as well)

1.2001 2020-10-22
- incomplete package, preparation in progress
- documentation improvements
- added file MANIFEST
- added:
   dpc-software/samples/index.cgi
   dpc-software/samples/login.cgi
   dpc-software/samples/logout.cgi
   dpc-software/samples/problems.cgi
   dpc-software/samples/codeview.cgi
   dpc-software/samples/feedbackview.cgi
   dpc-software/samples/adminview.cgi
   dpc-software/samples/style-dpc-3.css
   dpc-software/samples/templates/dpc-3.html.sfish
   dpc-software/samples/images/dpc-logo2.png

1.20 2020-10-03 Vlado Keselj https://vlado.ca vlado@dnlp.ca
- incomplete package, preparation in progress
- created the github repository
