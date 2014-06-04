######################################################################
#
# EPrints::DataObj::Thumbnail
#
######################################################################
#
#
######################################################################

package EPrints::DataObj::Thumbnail;

@ISA = ( 'EPrints::DataObj::File' );

use EPrints;
use Digest::MD5;
use MIME::Base64 ();

use strict;

######################################################################

=head2 Constructor Methods

=cut

######################################################################

=item $dataobj = EPrints::DataObj::File->new_from_filename( $repository, $dataobj, $filename )

Convenience method to get an existing File object for $filename stored in $dataobj.

Returns undef if no such record exists.

=cut

sub new_from_type
{
	my( $class, $repo, $file, $type ) = @_;
	
	return undef if !EPrints::Utils::is_set( $type );

	my $dataset = $repo->dataset( $class->get_dataset_id );

	my $results = $dataset->search(
		filters => [
			{
				meta_fields => [qw( datasetid )],
				value => $file->dataset->base_id,
				match => "EX",
			},
			{
				meta_fields => [qw( objectid )],
				value => $file->id,
				match => "EX",
			},
			{
				meta_fields => [qw( fieldname )],
				value => "thumbnails",
				match => "EX",
			},
			{
				meta_fields => [qw( type )],
				value => $type,
				match => "EX",
			},
		]);

	return $results->item( 0 );
}


######################################################################

=head2 Class Methods

=cut

######################################################################

=item $thing = EPrints::DataObj::File->get_system_field_info

Core fields.

=cut

sub get_system_field_info
{
	my( $class ) = @_;

	return
	( 
		{ name=>"thumbnailid", type=>"counter", required=>1, import=>0,
			can_clone=>0, sql_counter=>"thumbnailid" },

		{ name=>"datasetid", type=>"id", text_index=>0, import=>0, export => 0,
			can_clone=>0 }, 

		{ name=>"objectid", type=>"int", import=>0, can_clone=>0, export => 0 }, 
		
		{ name=>"fieldname", type=>"id", import=>0, can_clone=>0, export => 0 }, 
		
		{ name=>"fieldpos", type=>"int", import=>0, can_clone=>0, export => 0 }, 

		{ name=>"filename", type=>"id", export => 0 },

# sf2 eg "small", "large", "mp4"...
		{ name =>"type", type => "id" },

		{ name=>"mime_type", type=>"id", sql_index=>0, export => 0 },

		{ name=>"hash", type=>"id", maxlength=>64, export => 0 },

		{ name=>"hash_type", type=>"id", maxlength=>32, export => 0 },

		{ name=>"filesize", type=>"bigint", sql_index=>0 },

		{ name=>"url", type=>"url", virtual=>1 },

		{ name=>"data", type=>"base64", virtual=>1 },

		{
			name=>"copies", type=>"compound", multiple=>1, export => 0,
			fields=>[{
				name=>"pluginid",
				type=>"id",
			},{
				name=>"sourceid",
				type=>"id",
			}],
		},
	);
}

######################################################################
=pod

=item $dataset = EPrints::DataObj::File->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut
######################################################################

sub get_dataset_id
{
	return "thumbnail";
}


=item $content_length = $stored->set_file( CONTENT, $content_length )

Write $content_length bytes from CONTENT to the file object. Updates C<filesize> and C<hash> (you must call L</commit>).

Returns $content_length or undef on failure.

CONTENT may be one of:

=over 4

=item CODEREF

Will be called until it returns empty string ("").

=item SCALARREF

A scalar reference to a string of octets that will be written as-is.

=item GLOB

Will be treated as a file handle and read with sysread().

=back

=cut

sub set_file
{
	my( $self, $content, $clen ) = @_;

	$self->{repository}->get_storage->delete( $self );

	$self->set_value( "filesize", 0 );
	$self->set_value( "hash", undef );
	$self->set_value( "hash_type", undef );

	return 0 if $clen == 0;

	use bytes;
	# on 32bit platforms this will cause wrapping at 2**31, without integer
	# Perl will wrap at some much larger value (so use 64bit O/S!)
#	use integer;

	# calculate the MD5 as the data goes past
	my $md5 = Digest::MD5->new;

	my $f;
	if( ref($content) eq "CODE" )
	{
		$f = sub {
				my $buffer = &$content;
				$md5->add( $buffer );
				return $buffer;
			};
	}
	elsif( ref($content) eq "SCALAR" )
	{
		return 0 if length($$content) == 0;

		my $i = 0;
		$f = sub {
				return "" if $i++;
				$md5->add( $$content );
				return $$content;
			};
	}
	else
	{
		binmode($content);
		$f = sub {
				return "" unless sysread($content,my $buffer,16384);
				$md5->add( $buffer );
				return $buffer;
			};
	}

	my $rlen = do {
		local $self->{data}->{filesize} = $clen;
		$self->{repository}->get_storage->store( $self, $f );
	};

	# no storage plugin or plugins failed
	if( !defined $rlen )
	{
		$self->{repository}->log( $self->get_dataset_id."/".$self->get_id."::set_file(".$self->get_value( "filename" ).") failed: No storage plugins succeeded" );
		return undef;
	}

	# read failed
	if( $rlen != $clen )
	{
		$self->{repository}->log( $self->get_dataset_id."/".$self->get_id."::set_file(".$self->get_value( "filename" ).") failed: expected $clen bytes but actually got $rlen bytes" );
		return undef;
	}

	$self->set_value( "filesize", $rlen );
	$self->set_value( "hash", $md5->hexdigest );
	$self->set_value( "hash_type", "MD5" );

	return $rlen;
}

sub thumbnail_types { [] }

sub thumbnail_plugin {}

sub remove_thumbnails {}

sub make_thumbnails {}


1;

__END__

=back

=head1 SEE ALSO

L<EPrints::DataObj> and L<EPrints::DataSet>.

=cut


=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

