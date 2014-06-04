######################################################################
#
# EPrints::RepositoryConfig
#
######################################################################
#
#
######################################################################

=pod

=for Pod2Wiki

=head1 NAME

B<EPrints::RepositoryConfig> - Repository Configuration

=head1 SYNOPSIS

	$c->add_dataset_field( "eprint", {
		name => "title",
		type => "longtext",
	}, reuse => 1 );
	
	$c->add_trigger( EP_TRIGGER_URL_REWRITE, sub {
		my( %params ) = @_;
	
		my $r = $params{request};
	
		my $uri = $params{uri};
		if( $uri =~ m{^/blog/} )
		{
			$r->err_headers_out->{Location} = "http://...";
			${$params{rc}} = EPrints::Const::HTTP_SEE_OTHER;
			return EP_TRIGGER_DONE;
		}
	
		return EP_TRIGGER_OK;
	});

=head1 DESCRIPTION

This provides methods for reading and setting a repository configuration.
Setter methods may only be used in the configuration.

=head1 METHODS

=head2 Setter Methods

=over 4

=cut

package EPrints::RepositoryConfig;

use strict;

=item $c->add_dataset_trigger( $datasetid, TRIGGER_ID, $f, %opts )

Register a function reference $f to be called when the TRIGGER_ID event happens on $datasetid.

See L<EPrints::Const> for available triggers.

See L</add_trigger> for %opts.

=cut

sub add_dataset_trigger
{
	my( $self, $datasetid, $type, $f, %opts ) = @_;

	if( $self->read_only ) { EPrints::abort( "Configuration is read-only." ); }

	if( ref($f) ne "CODEREF" && ref($f) ne "CODE" )
	{
		EPrints->abort( "add_dataset_trigger expected a CODEREF but got '$f'" );
	}

	my $priority = exists $opts{priority} ? $opts{priority} : 0;

	push @{$self->{datasets}->{$datasetid}->{triggers}->{$type}->{$priority}}, $f;
}

=item $c->add_trigger( TRIGGER_ID, $f, %opts )

Register a function reference $f to be called when the TRIGGER_ID event happens.

See L<EPrints::Const> for available triggers.

Options:

	priority - used to determine the order triggers are executed in (defaults to 0).

=cut

sub add_trigger
{
	my( $self, $type, $f, %opts ) = @_;

	if( $self->read_only ) { EPrints::abort( "Configuration is read-only." ); }

	if( ref($f) ne "CODEREF" && ref($f) ne "CODE" )
	{
		EPrints->abort( "add_trigger expected a CODEREF but got '$f'" );
	}

	my $priority = exists $opts{priority} ? $opts{priority} : 0;

	push @{$self->{triggers}->{$type}->{$priority}}, $f;
}

=item $c->add_dataset_field( $datasetid, $fielddata, %opts )

Add a field spec $fielddata to dataset $datasetid.

This method will abort if the field already exists and 'reuse' is unspecified.

Options:
	reuse - re-use an existing field if it exists (must be same type)

=cut

sub add_dataset_field
{
	my( $c, $datasetid, $fielddata, %opts ) = @_;

	$c->{fields}->{$datasetid} = [] if !exists $c->{fields}->{$datasetid};

	my $reuse = $opts{reuse};

	for(@{$c->{fields}->{$datasetid}})
	{
		if( $_->{name} eq $fielddata->{name} )
		{
			if( !$reuse )
			{
				EPrints->abort( "Duplicate field name encountered in configuration: $datasetid.$_->{name}" );
			}
			elsif( $_->{type} ne $fielddata->{type} )
			{
				EPrints->abort( "Attempt to reuse field $datasetid.$_->{name} but it is a different type: $_->{type} != $fielddata->{type}" );
			}
			else
			{
				return;
			}
		}
	}

	push @{$c->{fields}->{$datasetid}}, $fielddata;
}



# sf2 - generalising roles and privs (ACL)

=pod
$c->define_role( 'public', [qw{
        +subject/rest/get
        +movie/view
        +movie/export
        +image/view
        +image/export
        +image/create
        +file/view
        +file/export
}] );
=cut

sub define_role
{
	my( $c, $role, $privs ) = @_;

	$privs ||= [];

	if( !EPrints::Utils::is_set( $role ) || ref( $privs ) ne 'ARRAY' )
	{
		# EPrints->warn( "Usage: \$c->define_role( role, [priv1, priv2, ...] )" );
		return;
	}

	# if the role exists this would redefine it.
	$c->{roles}->{$role} = $privs;
}

=pod
$c->add_public_roles( 'public' );

# set a pre-defined role to be public (ie. no user required to perform the allowed actions)

=cut

sub add_public_roles
{
	my( $c, @roles ) = @_;
	
	$c->{public_roles} ||= {};

	foreach my $role (@roles)
	{
		next if( !exists $c->{roles}->{$role} );
		$c->{public_roles}->{$role} = 1;

		$c->process_public_privs( @{$c->{roles}->{$role} || [] } );
	}
}

sub process_public_privs
{
	my( $c, @privs ) = @_;

	foreach my $priv ( @privs )
	{
		if( $priv =~ /^\+(.*)$/ )
		{
			$c->{public_privs}->{$1} = 1;
		}
		elsif( $priv =~ /^\-(.*)$/ )
		{
			delete $c->{public_privs}->{$1};
		}
	}
}


# Non advertised methods!

sub set_read_only
{
	my( $self ) = @_;
	$self->{".read_only"} = 1;	
}

sub unset_read_only
{
	my( $self ) = @_;
	$self->{".read_only"} = 0;	
}

sub read_only
{
	my( $self ) = @_;

	return( defined $self->{".read_only"} && $self->{".read_only"} );
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

