=head1 NAME

EPrints::Plugin::Screen::EPrint::UploadMethod::File

=cut

package EPrints::Plugin::Screen::EPrint::UploadMethod::File;

use EPrints::Plugin::Screen::EPrint::UploadMethod;

@ISA = qw( EPrints::Plugin::Screen::EPrint::UploadMethod );

use strict;

sub new
{
	my( $self, %params ) = @_;

	return $self->SUPER::new(
		flags => [
			metadata => "",
			media => "",
			bibliography => "",
		],
		appears => [
			{ place => "upload_methods", position => 200 },
		],
		actions => [qw( add_format )],
		%params );
}

sub allow_add_format { shift->can_be_viewed }

sub action_add_format
{
	my( $self ) = @_;
	
	my $session = $self->{session};
	my $processor = $self->{processor};
	my $eprint = $processor->{eprint};
	my $flags = $self->param_flags();

	return if !$self->SUPER::action_add_format();

	my $epdata = $processor->{notes}->{epdata};

	my $filename = $epdata->{main};
	return if !defined $filename;

	my $list;
	if( scalar grep { $_ } values %$flags )
	{
		$list = $self->parse_and_import( $epdata );
		if( !defined($list) )
		{
			$processor->add_message( "warning", $self->html_phrase( "unsupported_format" ) );
		}
	}
	if( !defined $list )
	{
		my $doc = $eprint->create_subdataobj( "documents", $epdata );
		if( defined $doc )
		{
			$list = EPrints::List->new(
				session => $session,
				dataset => $doc->dataset,
				ids => [$doc->id]
			);
		}
	}

	if( !defined $list || $list->count == 0 )
	{
		$processor->add_message( "error", $session->html_phrase( "Plugin/InputForm/Component/Upload:create_failed" ) );
		return;
	}

	for(@{$list->ids})
	{
		$processor->{notes}->{upload_plugin}->{to_unroll}->{$_} = 1;
	}
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

