#!/usr/local/bin/perl -w

################################################################################
# check_mail_server.pl
#
# Plugin to check that that we can connect to a given mail server
#
# TDBA 2014-06-26 - First version
# TDBA 2014-07-16 - Heavy modification, so we can see exactly where the connection
#                   falls over
################################################################################
# GLOBAL DECLARATIONS
################################################################################
use warnings;
use strict;
use Nagios::Plugin;
use File::Basename;
use IO::Socket::SSL;
use Time::HiRes qw(gettimeofday);

# Set version number
my $VERSION    = "1.1.0 [2014-07-16]";
my $SHORT_NAME = "MAIL SERVER"; 

# Set up default warn and critical times
my $DEF_WARN_TIME = 2;
my $DEF_CRIT_TIME = 4;

# Set up default connection and login timeout threshold
my $DEF_CONN_TIMEOUT  = 10;
my $DEF_LOGIN_TIMEOUT = 10;

# Set name of password file
my $PWD_FILE = dirname($0) . "/.imap";
################################################################################
# MAIN BODY
################################################################################

# Create the usage message
my $usage_msg  = qq(Usage: %s -s <mail_server> -u <user> [-p <port>] [-l]");

# Create the Nagios plugin
my $nagios = Nagios::Plugin->new(shortname => $SHORT_NAME, usage => $usage_msg, version => $VERSION);

# Add command line arguments
$nagios->add_arg("s=s", "-s <mail_server>\n   Mail server to connect to", undef, 1);
$nagios->add_arg("u=s", "-u <user>\n   User account on the mail server to connect against",  undef, 1);
$nagios->add_arg("p=i", "-p <port>\n   Port number to connect to", undef, 0);
$nagios->add_arg("w=i", "-w <warn>\n   Warn if connection time is longer than <warn> seconds (default: $DEF_WARN_TIME)", $DEF_WARN_TIME, 0);
$nagios->add_arg("c=i", "-w <crit>\n   Critical if connection time is longer than <crit> seconds (default: $DEF_CRIT_TIME)", $DEF_CRIT_TIME, 0);
$nagios->add_arg("l",   "-l\n   Connect using SSL", 0, 0);

# Parse command line arguments
$nagios->getopts;

# Get the connection variables
my $use_ssl    = $nagios->opts->l;
my $server     = $nagios->opts->s;
my $user       = $nagios->opts->u;
my $port       = ($nagios->opts->p) ? $nagios->opts->p : (($use_ssl) ? 993 : 143);
my $connection = { PeerAddr => $server, PeerPort => $port, Timeout => $DEF_CONN_TIMEOUT, Proto => "tcp", SSL_verify_mode => 0 };
my $password   = get_password($server, $user);

# Set the connection time threshold
$nagios->set_thresholds(warning => $nagios->opts->w, critical => $nagios->opts->c);

# Start the clock
my $start_time = gettimeofday;

# Connect to socket
my $socket =  IO::Socket::SSL->new(%$connection) or $nagios->nagios_exit(2, sprintf("Could not connect to IMAP server %s: %s", $server, $SSL_ERROR));

# Check to ensure we can select the socket in time
my $select = IO::Select->new($socket);
if ($select->can_read($DEF_CONN_TIMEOUT))
{
   # Check if we can get a line. Then, check if it is OK
   if (my $line = $socket->getline)
   {
      if ($line !~ m/^\*\s+(?:OK|PREAUTH)/i) { $nagios->nagios_exit(2, sprintf("Bad greeting line: %s", $line)); }
   }
   else { $nagios->nagios_exit(2, sprintf("Unable to get a greeting line")); }
}
else { $nagios->nagios_exit(2, sprintf("Timed out while trying to connect to IMAP server %s", $server)); }

# Now attempt the log in
my $login_cmd = sprintf("0 LOGIN %s %s\r\n", $user, $password);
{ local $\; print $socket $login_cmd; }
if ($select->can_read($DEF_LOGIN_TIMEOUT))
{
   if (my $res = $socket->getline)
   {
      if    ($res =~ m/^0\s+(?:NO|BAD)(?:\s+(.+))?/i) { $nagios->nagios_exit(2, sprintf("Unknown login error: %s", $res));   }
      elsif ($res !~ m/^0\s+OK/i)                     { $nagios->nagios_exit(2, sprintf("Unknown return string: %s", $res)); }
   }
   else { $nagios->nagios_exit(2, sprintf("Unable to get line after login")); }
}
else { $nagios->nagios_exit(2, sprintf("Timed out while trying to login to IMAP server %s as %s", $server, $user)); }

# We have connected successfully! Now quit IMAP
my $logout_cmd = sprintf("0 LOGOUT\r\n");
{ local $\; print $socket $logout_cmd; }

# Stop the clock
my $end_time = gettimeofday;

# Find the time taken to connect and log in
my $duration = $end_time - $start_time;

# Check the value falls within the threshold and return appropriate value
my $status = $nagios->check_threshold($duration);

# Set the performance data
$nagios->add_perfdata(label => "time", value => sprintf("%.3f", $duration), uom => "s", threshold => $nagios->threshold());

# Exit from Nagios
$nagios->nagios_exit(0, sprintf("Successfully connected to IMAP server %s as '%s'", $server, $user));
################################################################################
# SUBROUTINES
################################################################################
sub get_password # Gets password from password file, using mail server and user name
{
    my ($server, $user) = @_;

    open(FILE, $PWD_FILE) or $nagios->nagios_die("Cannot open password file for reading!");
    while (my $line = <FILE>)
    {
       chomp $line;
       my ($s, $u, $p) = split(/\:/, $line);

       if (($s eq $server) && ($u eq $user)) { return $p; }
    }

    return "";
}
################################################################################
# DOCUMENTATION
################################################################################

=head1 NAME

check_mail_server.pl - Plugin to check that that we can connect to a given IMAP mail server

=head1 SYNOPSIS

B<check_mail_server.pl> B<-s> I<mail_server> B<-u> I<user> [B<-p> I<port>] [B<-l>]

=head1 DESCRIPTION

B<check_mail_server.pl> will attempt to connect to the I<user> on I<mail_server> and send out an alarm if it 
either fails to connect or does not connect in a timely manner.

=head1 REQUIREMENTS

The following Perl modules are required in order for this script to work:

 * Nagios::Plugin;
 * File::Basename;
 * IO::Socket::SSL;
 * Time::HiRes qw(gettimeofday);

A file containing the connection parameters also needs to be present. This file is called ".imap" by default and should be placed
in the same directory as this script.

=head1 OPTIONS

B<-s> I<mail_server>

Specifies the name of the mail server to connect to.

B<-u> I<user>

Specifies the user account on the mail server to connect against.

B<-p> I<port>

Optionally specifies a port number to connect to.

B<-l>

Connect to the mail server using SSL.

=head1 CONNECTION FILE SPECIFICATION

The connection file B<.imap> is a colon-separated file containing the servers, usernames and passwords to connect as. Passwords will
be stored in plain text, however the script has to be able to read this file so set the permissions of this file accordingly. The format
of a line in this file is "server:username:password". 

=head1 EXAMPLE

./check_mail_server.pl -s "mail.server" -u "foo" -l

Attempts to connect to the IMAP server "mail.server" as user "foo" over SSL.

=head1 USE IN NAGIOS

When using this script in Nagios, you may have to specify the full path to your Perl binary, in your command definition, otherwise 
the B<.imap> file may not be found. For example:

 define command{
         command_name    check_mail_server
         command_line    /usr/bin/perl $USER1$/check_mail_server.pl -s "$ARG1$" -u "$ARG2$" "$ARG3$"
 }

=head1 ACKNOWLEDGEMENT

This documentation is available as POD and reStructuredText, with the conversion from POD to RST being carried out by B<pod2rst>, which is 
available at http://search.cpan.org/~dowens/Pod-POM-View-Restructured-0.02/bin/pod2rst

=head1 AUTHOR

Tim Barnes E<lt>tdba[AT]bas.ac.ukE<gt> - British Antarctic Survey, Natural Environmental Research Council, UK

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Tim Barnes, British Antarctic Survey, Natural Environmental Research Council, UK

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut
