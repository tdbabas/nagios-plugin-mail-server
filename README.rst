.. highlight:: perl


****
NAME
****


check_mail_server.pl - Plugin to check that that we can connect to a given IMAP mail server


********
SYNOPSIS
********


\ **check_mail_server.pl**\  \ **-s**\  \ *mail_server*\  \ **-u**\  \ *user*\  [\ **-p**\  \ *port*\ ] [\ **-l**\ ]


***********
DESCRIPTION
***********


\ **check_mail_server.pl**\  will attempt to connect to the \ *user*\  on \ *mail_server*\  and send out an alarm if it 
either fails to connect or does not connect in a timely manner.


************
REQUIREMENTS
************


The following Perl modules are required in order for this script to work:


.. code-block:: perl

  * Nagios::Plugin;
  * File::Basename;
  * IO::Socket::SSL;
  * Time::HiRes qw(gettimeofday);


A file containing the connection parameters also needs to be present. This file is called ".imap" by default and should be placed
in the same directory as this script.


*******
OPTIONS
*******


\ **-s**\  \ *mail_server*\ 

Specifies the name of the mail server to connect to.

\ **-u**\  \ *user*\ 

Specifies the user account on the mail server to connect against.

\ **-p**\  \ *port*\ 

Optionally specifies a port number to connect to.

\ **-l**\ 

Connect to the mail server using SSL.


*****************************
CONNECTION FILE SPECIFICATION
*****************************


The connection file \ **.imap**\  is a colon-separated file containing the servers, usernames and passwords to connect as. Passwords will
be stored in plain text, however the script has to be able to read this file so set the permissions of this file accordingly. The format
of a line in this file is "server:username:password".


*******
EXAMPLE
*******


./check_mail_server.pl -s "mail.server" -u "foo" -l

Attempts to connect to the IMAP server "mail.server" as user "foo" over SSL.


*************
USE IN NAGIOS
*************


When using this script in Nagios, you may have to specify the full path to your Perl binary, in your command definition, otherwise 
the \ **.imap**\  file may not be found. For example:


.. code-block:: perl

  define command{
          command_name    check_mail_server
          command_line    /usr/bin/perl $USER1$/check_mail_server.pl -s "$ARG1$" -u "$ARG2$" "$ARG3$"
  }



***************
ACKNOWLEDGEMENT
***************


This documentation is available as POD and reStructuredText, with the conversion from POD to RST being carried out by \ **pod2rst**\ , which is 
available at http://search.cpan.org/~dowens/Pod-POM-View-Restructured-0.02/bin/pod2rst


******
AUTHOR
******


Tim Barnes <tdba[AT]bas.ac.uk> - British Antarctic Survey, Natural Environmental Research Council, UK


*********************
COPYRIGHT AND LICENSE
*********************


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

