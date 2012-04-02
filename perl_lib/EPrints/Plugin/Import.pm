=for Pod2Wiki

=head1 NAME

EPrints::Plugin::Import

=head1 METHODS

=over 4

=cut

package EPrints::Plugin::Import;

use strict;

our @ISA = qw/ EPrints::Plugin /;

$EPrints::Plugin::Import::DISABLE = 1;

=item $plugin = EPrints::Plugin::Import->new( %opts )

Create a new Import plugin. Available options:

=over 4

=item accept

Array reference of acceptable MIME types.

=item actions

Array reference of named actions.

=item advertise

Boolean for whether to advertise this plugin to users.

=item arguments

Hash reference of supported arguments/default values.

=item Handler

Reference to a handler class, typically L<EPrints::CLIProcessor> or L<EPrints::ScreenProcessor>.

=item produce

Array reference of eprint types this plugin can produce.

=item screen

The screen id this plugin uses to provide its import UI.

=item visible

"staff" (staff only) or "all" (anyone).

=back

=cut

sub new
{
	my( $class, %params ) = @_;

	$params{produce} = exists $params{produce} ? $params{produce} : [];
	$params{visible} = exists $params{visible} ? $params{visible} : "all";
	$params{advertise} = exists $params{advertise} ? $params{advertise} : 1;
	$params{session} = exists $params{session} ? $params{session} : $params{processor}->{session};
	$params{actions} = exists $params{actions} ? $params{actions} : [];
	$params{arguments} = exists $params{arguments} ? $params{arguments} : {};
	$params{Handler} = exists $params{Handler} ? $params{Handler} : EPrints::CLIProcessor->new( session => $params{session} );
	$params{screen} = exists $params{screen} ? $params{screen} : "Import";
	$params{accept} = exists $params{accept} ? $params{accept} : [$class->mime_type];

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

	for(@{$self->param( "accept" )}, $self->mime_type)
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

=item $dataobj = $plugin->epdata_to_dataobj( $epdata, %opts )

Turn $epdata into a L<EPrints::DataObj> with the dataset passed in %opts.

Calls handler to perform the actual creation.

=cut

sub epdata_to_dataobj
{
	# backwards compatibility
	my( $dataset ) = splice(@_,1,1)
		if UNIVERSAL::isa( $_[1], "EPrints::DataSet" );
	my( $self, $epdata, %opts ) = @_;
	$opts{dataset} ||= $dataset;

	if( $dataset->id eq "eprint" && !defined $epdata->{eprint_status} )
	{
		$self->warning( "Importing an EPrint record into 'eprint' dataset without eprint_status being set. Using 'buffer' as default." );
		$epdata->{eprint_status} = "buffer";
	}
	
	return $self->handler->epdata_to_dataobj( $epdata, %opts );
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

=back

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2012 University of Southampton.

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

