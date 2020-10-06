# dpc-system - DPC System for Programming Contests and Practicums

Status: The code is in process of making the system open source.
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

## ChangeLog

1.2001 currently under development

1.20 2020-10-03 Vlado Keselj https://vlado.ca vlado@dnlp.ca
 - created the github repository
