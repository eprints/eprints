=head1 NAME

EPrints::Plugin::Search::ISIWoK

=cut

package EPrints::Plugin::Search::ISIWoK;

use base qw( EPrints::Plugin::Search::External EPrints::List::Cache );

use strict;

our @WOS_INDEXES = (
		AD => 'Address',
		AU => 'Author',
		CA => 'Cited Author',
		CI => 'City',
		CT => 'Conference',
		CU => 'Country',
		CW => 'Cited Work',
		CY => 'Cited Year',
		DT => 'Document Type',
		GP => 'Group Author',
		LA => 'Language',
		OG => 'Organization',
		PS => 'Province/State',
		PY => 'Pub Year',
		SA => 'Street Address',
		SG => 'Sub-organization',
		SO => 'Source',
		TI => 'Title',
		TS => 'Topic',
		UT => 'ISI UT identifier',
		ZP => 'Zip/Postal Code',
	);

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{disable} = !EPrints::Utils::require_if_exists( "SOAP::ISIWoK", "3.00" );
	$self->{q} = {};

	return $self;
}

sub _isiwok
{
	my ($self) = @_;

	return $self->{wok} if $self->{wok};

	my $wok = $self->{wok} = $self->param('lite') ?
		SOAP::ISIWoK::Lite->new :
		SOAP::ISIWoK->new;

	my $som = $wok->authenticate(
			$self->param('username'),
			$self->param('password')
		);
	die $som->faultstring if $som->fault;

	return $wok;
}

sub from_form
{
	my( $self, $basename ) = @_;

	my @problems;

	my @parts;

	for(my $i = 0; $i < @WOS_INDEXES; $i+=2)
	{
		my( $key, undef ) = @WOS_INDEXES[$i,$i+1];
		my $v = $self->repository->param( join('_', $basename, $key) );
		next if !EPrints::Utils::is_set( $v );
		$self->{q}->{$key} = $v;
	}

	return @problems;
}

sub from_string_fields
{
	my( $self, $fields ) = @_;

	my $uri = URI::http->new( $fields->[0] );
	%{$self->{q}} = $uri->query_form;

	return 1;
}

sub serialise_fields
{
	my( $self ) = @_;

	my $uri = URI::http->new;
	$uri->query_form( map { $_ => $self->{q}->{$_} } sort keys %{$self->{q}} );

	return "$uri";
}

sub render_input
{
	my( $self, $basename, %opts ) = @_;

	my $repo = $self->repository;
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $frag = $xml->create_document_fragment;

	$frag->appendChild( $self->html_phrase( "help" ) );

	my $table = $frag->appendChild( $xml->create_element( "table" ) );

	for(my $i = 0; $i < @WOS_INDEXES; $i+=2)
	{
		my( $key, undef ) = @WOS_INDEXES[$i,$i+1];
		my $param_key = join '_', $basename, $key;
		$table->appendChild( $repo->render_row_with_help(
				label => $self->html_phrase( "field:$key" ),
				field => $repo->render_input_field(
					class => "ep_form_text",
					type => "text",
					name => join('_', $basename, $key),
					value => $self->{q}->{$key},
					maxlength => 256 ),
			) );
	}

	$frag->appendChild( $xhtml->input_field(
		_action_search => $repo->phrase( "lib/searchexpression:action_search" ),
		type => "submit",
		class => "ep_form_action_button",
	) );

	return $frag;
}

sub execute
{
	my( $self ) = @_;

	my $dataset = $self->repository->dataset( "cache_dataobj_map" );

	if( defined $self->{cache_id} )
	{
		$self->{cache} = $dataset->dataobj( $self->{cache_id} );
	}

	if( !defined $self->{cache} )
	{
		my $result = eval { $self->_query( 0 ) };
		if( $@ )
		{
			if( $self->{processor} )
			{
				$@ =~ s/at \/.*$//s;
				$self->{processor}->add_message(
					"error",
					$self->repository->xml->create_text_node( "WoK responded with: $@" )
				);
			}
			return;
		}

		$self->{cache} = $dataset->create_dataobj({
				searchexp => $self->freeze,
				available => 0,
				count => $result->{"recordsFound"},
			});
	}

	return $self;
}

# always cache
sub cache {}

sub count
{
	my( $self ) = @_;

	if( !defined $self->{count} )
	{
		$self->slice( 0, 10 );
	}

	return $self->{count};
}

sub _query
{
	my( $self, $offset ) = @_;

	my $wok = $self->_isiwok;

	my $q = join ' AND ', map {
			"($_ = $self->{q}->{$_})"
		} keys %{$self->{q}};

	my $som = $wok->search( $q, offset => $offset + 1 );
	die $som->faultstring if $som->fault;

	return $som->result;
}

sub slice
{
	my( $self, $offset, $count ) = @_;

	my $repo = $self->repository;

	my $cache = $self->{cache};

	my $cache_dataset = $repo->dataset( "cache_dataobj" );

	while( $cache->value( "available" ) < $offset + $count )
	{
		my $available = $cache->value( "available" );

		my $result = eval { $self->_query( $available ) };
		if( $@ )
		{
			if( $self->{processor} )
			{
				$@ =~ s/at \/.*$//s;
				$self->{processor}->add_message(
					"error",
					$self->repository->xml->create_text_node( "WoK responded with: $@" )
				);
			}
			return;
		}

		$cache->set_value( "count", $result->{"recordsFound"} );
		$cache->commit;

		my $import = $repo->plugin( "Import::ISIWoKXML",
			Handler => EPrints::CLIProcessor->new(
				message => sub { $self->{processor}->add_message(@_) },
				epdata_to_dataobj => sub {
					my ($epdata, %opts) = @_;
					$epdata->{eprint_status} = "inbox";
					$cache->create_subdataobj( "dataobjs", {
							pos => ++$available,
							datasetid => "eprint",
							epdata => $epdata,
						});
				},
			),
		);

		open(my $fh, "<", \$result->{records});
		$import->input_fh(
			fh => $fh,
			dataset => $repo->dataset('inbox'),
		);

		# nothing received
		last if $available == $cache->value( "available" );

		$cache->set_value( "available", $available );
		$cache->commit;
	}

	$self->{count} = $cache->value( "count" );

	return $cache->slice( $offset, $count );
}

sub describe
{
	my( $self ) = @_;

	return "ISIWoK($self->{q})";
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

