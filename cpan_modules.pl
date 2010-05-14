#!/usr/bin/perl
 
use CPAN;

#
# Set the umask so nothing goes odd on systems which
# change it.
#
umask( 0022 );


print "Attempting to install PERL modules required by GNU EPrints...\n";

install( 'Data::ShowTable' ); # used by DBD::mysql
install( 'DBI' ); # used by DBD::mysql
install( 'DBD::mysql' );
install( 'MIME::Base64' );
install( 'XML::Parser' );
install( 'Net::SMTP' );

# not required since 2.3.7
#foreach $mod_name ( "Apache::Test", "Apache::Request" )
#{
#	( $mod ) = expand( "Module",$mod_name );
#	if( $mod->uptodate ) { print "$mod_name is up to date.\n"; next; }
#	print "Installing $mod_name (without test)\n";
#	$mod->force; 
#	$mod->install;
#}

