######################################################################
#
# EPrints::Probity
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################


=pod

=head1 NAME

B<EPrints::Probity> - EPrints Probity Module

=head1 DESCRIPTION

Every time the files in an EPrint are modified, an checksum of the
all the EPrints files is written to a file. This is used in checking
the file hasn't been altered by some other means, and also can be
used to prove that the file existed on a given date.

See bin/export_hashes for more information.

=over 4

=cut

package EPrints::Probity;

use strict;

use URI;


######################################################################
=pod

=item $xml = EPrints::Probity::process_file( $handle, $filename, [$name] );

Process the given file and return an XML chunk in the format. 

 <hash>
    <name>/opt/eprints3/documents/disk0/00/00/05/04/02/stuff.pdf</name>
    <algorithm>SHA-1</algorithm>
    <value>cc7a32915ab0a73ba1f94b34d3a265bdccd3c8b9</value>
    <date>Fri Sep 27 10:53:10 BST 2002</date>
 </hash>

If $name is not specified then the name is $filename.

If there is a problem return a empty XML document fragment.

=cut
######################################################################

sub process_file
{
	my( $handle, $file ) = @_;

	my $filename = $file->get_value( "filename" );
	my $value = $file->get_value( "hash" );
	my $alg = $file->get_value( "hash_type" );

	my $hash = $handle->make_element( "hash" );
	$hash->appendChild( $handle->render_data_element( 6, "name", $filename ) );
	$hash->appendChild( $handle->render_data_element( 6, "algorithm", $alg ) );
	$hash->appendChild( $handle->render_data_element( 6, "value", $value ) );
	$hash->appendChild( $handle->render_data_element( 6, "date", EPrints::Time::get_iso_timestamp() ));

	return $hash;
}

######################################################################
=pod

=item $xml = EPrints::Probity::create_log( $handle, $files, [$outfile] )

Create an XML file $outfile of the format:

 <?xml version="1.0" encoding="UTF-8"?>
 <hashlist xmlns="http://probity.org/XMLprobity">
    <hash>
       <name>/opt/eprints3/documents/disk0/00/00/05/04/02/stuff.pdf</name>
       <algorithm>SHA-1</algorithm>
       <value>cc7a32915ab0a73ba1f94b34d3a265bdccd3c8b9</value>
       <date>Fri Sep 27 10:53:10 BST 2002</date>
    </hash>
    .
    .
    .

From the files in array ref $filenames.

If $outfile is not specified then the XML is sent to STDOUT.

=cut
######################################################################

sub create_log
{
	my( $handle, $files, $outfile ) = @_;

	my $fh;
	unless( open( $fh, ">$outfile" ) )
	{
		$handle->get_repository->log( "Error pening '$outfile' to write log: $!" );
		return;
	}
	create_log_fh( $handle, $files, $fh );
	close $fh;
}

sub create_log_fh
{
	my( $handle, $files, $fh ) = @_;

	my $hashlist = $handle->make_element( 
		"hashlist", 
		xmlns=>"http://probity.org/XMLprobity" );
	foreach my $file ( @{$files} )
	{
		$hashlist->appendChild( $handle->make_indent( 3 ) );
		$hashlist->appendChild( process_file( $handle, $file ) );
	}

	$fh = *STDOUT unless defined $fh;

	print $fh '<?xml version="1.0" encoding="UTF-8" ?>'."\n";
	print $fh $hashlist->toString."\n";

	EPrints::XML::dispose( $hashlist );
}
	

1;

######################################################################
=pod

=back

=cut
