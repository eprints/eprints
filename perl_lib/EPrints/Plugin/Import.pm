=head1 NAME

EPrints::Plugin::Import

=cut

package EPrints::Plugin::Import;

use strict;

our @ISA = qw/ EPrints::Plugin /;

$EPrints::Plugin::Import::DISABLE = 1;

=item $plugin = EPrints::Plugin::Import->new( %opts )

Create a new Import plugin. Available options:

=over 4

=item import_documents

If an eprint contains documents attempt to import them as well.

=item update

If the new item has the same identifier as an existing one, attempt to update the existing item.

=back

=cut

sub new
{
	my( $class, %params ) = @_;

	$params{accept} = exists $params{accept} ? $params{accept} : [];
	$params{produce} = exists $params{produce} ? $params{produce} : [];
	$params{visible} = exists $params{visible} ? $params{visible} : "all";
	$params{advertise} = exists $params{advertise} ? $params{advertise} : 1;
	$params{session} = exists $params{session} ? $params{session} : $params{processor}->{session};
	$params{actions} = exists $params{actions} ? $params{actions} : [];
	$params{arguments} = exists $params{arguments} ? $params{arguments} : {};
	$params{Handler} = exists $params{Handler} ? $params{Handler} : EPrints::CLIProcessor->new( session => $params{session} );

	return $class->SUPER::new(%params);
}

sub arguments { shift->EPrints::Plugin::Export::arguments( @_ ) }
sub has_argument { shift->EPrints::Plugin::Export::has_argument( @_ ) }

sub handler
{
	my( $plugin ) = @_;

	return $plugin->{Handler};
}

sub set_handler
{
	my( $plugin, $handler ) = @_;

	$plugin->{Handler} = $handler;
}

sub render_name
{
	my( $plugin ) = @_;

	return $plugin->{session}->make_text( $plugin->param("name") );
}

sub matches 
{
	my( $self, $test, $param ) = @_;

	if( $test eq "is_visible" )
	{
		return( $self->is_visible( $param ) );
	}
	if( $test eq "can_produce" )
	{
		return( $self->can_produce( $param ) );
	}
	if( $test eq "is_advertised" )
	{
		return( $self->param( "advertise" ) == $param );
	}
	if( $test eq "can_accept" )
	{
		return $self->can_accept( $param );
	}
	if( $test eq "can_action" )
	{
		return $self->can_action( $param );
	}

	# didn't understand this match 
	return $self->SUPER::matches( $test, $param );
}

sub can_action
{
	my( $self, $actions ) = @_;

	if( ref($actions) eq "ARRAY" )
	{
		for(@$actions)
		{
			return 0 if !$self->can_action( $_ );
		}
		return 1;
	}

	return $actions eq "*" ?
		scalar(@{$self->param( "actions" )}) > 0 :
		scalar(grep { $_ eq $actions } @{$self->param( "actions" )}) > 0;
}

# all, staff or ""
sub is_visible
{
	my( $plugin, $vis_level ) = @_;

	return( 1 ) unless( defined $vis_level );

	my $visible = $plugin->param("visible");
	return( 0 ) unless( defined $visible );

	if( $vis_level eq "all" && $visible ne "all" ) {
		return 0;
	}

	if( $vis_level eq "staff" && $visible ne "all" && $visible ne "staff" ) {
		return 0;
	}

	return 1;
}

sub can_accept
{
	my( $self, $format ) = @_;

	for(@{$self->param( "accept" )})
	{
		return 1 if (split /;/, $_)[0] eq $format;
	}

	return 0;
}

sub can_produce
{
	my( $plugin, $format ) = @_;

	my $produce = $plugin->param( "produce" );
	foreach my $a_format ( @{$produce} ) {
		if( $a_format =~ m/^(.*)\*$/ ) {
			my $base = $1;
			return( 1 ) if( substr( $format, 0, length $base ) eq $base );
		}
		else {
			return( 1 ) if( $format eq $a_format );
		}
	}

	return 0;
}

=item $plugin->input_fh( fh => FILEHANDLE [, %opts] )

Import one or more objects from filehandle FILEHANDLE. FILEHANDLE should be set to binary semantics.

This method should by subclassed.

=cut

sub input_fh
{
	my( $plugin, %opts ) = @_;

	return undef;
}

=item $plugin->input_file( filename => FILENAME [, %opts] )

Opens FILENAME for reading, sets binary semantics and calls input_fh to actually read the file.

This method may be subclassed (e.g. see L<EPrints::Plugin::Import::TextFile>).

=cut

sub input_file
{
	my( $plugin, %opts ) = @_;

	my $fh;
	if( $opts{filename} eq '-' )
	{
		$fh = *STDIN;
	}
	else
	{
		unless( open($fh, "<", $opts{filename}) )
		{
			$plugin->error("Could not open file $opts{filename} for import: $!");

			return undef;
		}
		binmode($fh);
	}
	$opts{fh} = $fh;

	my $list = $plugin->input_fh( %opts );

	unless( $opts{filename} eq '-' )
	{
		close($fh);
	}

	return $list;
}

sub input_dataobj
{
	my( $plugin, $input_data ) = @_;

	my $epdata = $plugin->convert_input( $input_data );

	return $plugin->epdata_to_dataobj( $plugin->{dataset}, $epdata ); 
}

sub convert_input
{
	my( $plugin, $input_data ) = @_;

	my $r = "error. convert_dataobj should be overridden";

	$plugin->log( $r );
}

sub epdata_to_dataobj
{
	my( $plugin, $dataset, $epdata, $dataobj ) = @_;

	my $session = $plugin->{session};

	my $item;

	if( $session->config( 'enable_import_fields' ) )
	{
		my $ds_id = $dataset->confid;
		if( $ds_id eq "eprint" || $ds_id eq "user" )
		{
			my $id = $epdata->{$dataset->get_key_field->get_name};
			if( $plugin->{update} )
			{
				$item = $dataset->get_object( $session, $id );
			}
			elsif( $session->get_database->exists( $dataset, $id ) )
			{
				$plugin->error("Failed attampt to import existing $ds_id.$id");
				return;
			}
		}
	}

	if( $dataset->confid eq "eprint" && exists($plugin->{import_documents}) && !$plugin->{import_documents} )
	{
		delete $epdata->{documents};
	}

	$plugin->handler->parsed( $epdata );
	return if( $plugin->{parse_only} );

	if( $dataset->id eq "eprint" && !defined $epdata->{eprint_status} && !defined $item )
	{
		$plugin->warning( "Importing an EPrint record into 'eprint' dataset without eprint_status being set. Using 'buffer' as default." );
		$epdata->{eprint_status} = "buffer";
	}
	# Update an existing item
	if( defined( $item ) )
	{
		foreach my $fieldname (keys %$epdata)
		{
			if( $dataset->has_field( $fieldname ) )
			{
				# Can't currently set_value on subobjects
				my $field = $dataset->get_field( $fieldname );
				next if $field->is_type( "subobject" );
				$item->set_value( $fieldname, $epdata->{$fieldname} );
			}
		}
		$item->commit();
	}
	# Add to existing
	elsif ( defined $dataobj ) 
	{
		$item = $dataobj->create_subdataobj( $dataset->confid.'s', $epdata );
	}
	# Create a new item 
	else
	{
		$item = $dataset->create_object( $plugin->{session}, $epdata );
	}

	if( defined( $item ) )
	{
		$plugin->handler->object( $dataset, $item );
	}

	return $item;
}

sub warning
{
	my( $plugin, $msg ) = @_;

	$plugin->handler->message( "warning", $plugin->{session}->make_text( $msg ));
}	

sub error
{
	my( $plugin, $msg ) = @_;

	$plugin->handler->message( "error", $plugin->{session}->make_text( $msg ));
}

sub is_tool
{
	return 0;
}

1;

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

