ISI SOAP API Harvester
----------------------

Copyright 2009 Tim Brody, University of Southampton.

This file is part of EPrints.

EPrints is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published
by the Free Software Foundation, either version 3 of the License,
or (at your option) any later version.

EPrints is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with EPrints.  If not, see <http://www.gnu.org/licenses/>.


Installation
------------

If you haven't already done so, unpack the WOS tarball to your EPrints root
directory (typically /opt/eprints3).

Install the SOAP::Lite and XML::LibXML Perl libraries (along with any
dependencies).

To install these using CPAN (you may prefer to use your platform's package
manager):

$ cpan
> install SOAP::Lite
> install XML::LibXML

Copy or link the configuration file tools/isi_citations/zz_wos.pl into your
cfg.d directory (archives/[repoid]/cfg/cfg.d).

Run the update_database_structure command:

$ ./bin/epadmin update_database_structure [repoid]

It should add a "wos" metadata field to your eprint dataset.


Configuring
-----------

The zz_wos.pl file contains several configuration options. The first is the
field used to store the ISI citation data (you shouldn't alter this).

The "filters" option controls which EPrints will be queried for in ISI.

The "query_builder" method controls how ISI will be queried, by default using
first author and full title. If the query used is too imprecise more than one
record will match which will cause the update to fail.


Running the ISI Update Command
------------------------------

If your EPrints is installed in /opt/eprints3 you can simply run:

$ perl tools/isi_citations.pl [repoid]

If your EPrints is installed elsewhere do:

$ PERL5LIB=/path/to/eprints/perl_lib perl tools/isi_citations.pl [repoid]

You may optionally specify the --verbose command to increase the amount of
feedback.

You may specify a list of eprint ids to process after the [repoid].


Last updated 2009-05-07
