=head1 NAME

EPrints::Plugin::Issues

=head1 SYNOPSIS

	my $plugin = $repo->plugin( "Issues::..." );

	$plugin->process_dataobj( $eprint );
	$plugin->finish;

	$list = $repo->dataset( "eprint" )->search;

	$plugin->process_list( list => $list );
	$plugin->finish;

=head1 METHODS

=over 4

=cut

package EPrints::Plugin::Issues;

use strict;

our @ISA = qw/ EPrints::Plugin /;

$EPrints::Plugin::Issues::DISABLE = 1;

sub new
{
	my( $self, %params ) = @_;

	$params{accept} = [] if !exists $params{accept};
	$params{Handler} = EPrints::CLIProcessor->new( session => $params{session} )
		if !exists $params{Handler};

	return $self->SUPER::new( %params );
}

sub handler
{
	my( $self ) = @_;

	return $self->{Handler};
}

sub set_handler
{
	my( $self, $handler ) = @_;

	return $self->{Handler} = $handler;
}

sub matches 
{
	my( $self, $test, $param ) = @_;

	if( $test eq "can_accept" )
	{
		return( $self->can_accept( $param ) );
	}

	# didn't understand this match 
	return $self->SUPER::matches( $test, $param );
}

sub can_accept { shift->EPrints::Plugin::Export::can_accept( @_ ) }

=item $issue = $plugin->create_issue( $parent, $epdata [, %opts ] )

Utility method to create a new issue for $parent from $epdata.

=cut

sub create_issue
{
	my( $self, $parent, $epdata, %opts ) = @_;

	# set the parent, without side-effecting
	local $epdata->{datasetid} = $parent->{dataset}->base_id;
	local $epdata->{objectid} = $parent->id;

	return $self->handler->epdata_to_dataobj( $epdata,
			%opts,
			dataset => $self->repository->dataset( "issue" ),
		);
}

=item $plugin->process_list( list => $list [, %opts ] )

Process a L<EPrints::List> of items. Call L</finish> to perform any summary-data actions.

=cut

sub process_list
{
	my( $self, %opts ) = @_;

	$opts{list}->map(sub {
		(undef, undef, my $item) = @_;

		$self->process_dataobj( $item, %opts );
	});
}

=item $plugin->process_dataobj( $dataobj [, %opts ] )

Process a single L<EPrints::DataObj>. Call L</finish> to perform any summary-data actions.

=cut

sub process_dataobj
{
	my( $self, $item, %opts ) = @_;

	# nothing to do
}

=item $plugin->finish

Finish processing for issues and clean-up any state information stored in the plugin.

=cut

sub finish
{
	my( $self, %opts ) = @_;
}

1;

=back

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

