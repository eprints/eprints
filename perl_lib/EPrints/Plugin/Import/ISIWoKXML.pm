=head1 NAME

EPrints::Plugin::Import::ISIWoKXML

=cut

package EPrints::Plugin::Import::ISIWoKXML;

use base qw( EPrints::Plugin::Import );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "ISI Web of Knowledge XML";
	$self->{visible} = "all";
	$self->{advertise} = 0;
	$self->{produce} = [ 'list/eprint' ];

	return $self;
}

sub input_fh
{
	my( $self, %opts ) = @_;

	my $session = $self->{session};
	my $dataset = $opts{dataset};

	my @ids;

	my $handler = EPrints::Plugin::Import::ISIWoKXML::Handler->new(
			epdata_to_dataobj => sub {
				my $dataobj = $self->epdata_to_dataobj($dataset, $_[0]);
				push @ids, $dataobj->id if defined $dataobj;
			},
		);

	EPrints::XML::event_parse(
		$opts{fh},
		$handler,
	);

	return EPrints::List->new(
		session => $session,
		dataset => $dataset,
		ids => \@ids );
}

package EPrints::Plugin::Import::ISIWoKXML::Handler;

sub AUTOLOAD {}

my %month_map = (
	Jan => '-01',
	Feb => '-02',
	Mar => '-03',
	Apr => '-04',
	May => '-05',
	Jun => '-06',
	Jul => '-07',
	Aug => '-08',
	Sep => '-09',
	Oct => '-10',
	Nov => '-11',
	Dec => '-12',
);

sub new
{
	my ($class, %self) = @_;

	return bless {
		%self,
		path => '',
		characters => undef,
	}, $class;
}

sub start_element
{
	my ($self, $data) = @_;

	no warnings;

	my %attr = map {
			substr($_,2) => $data->{Attributes}{$_}{Value}
		} keys %{$data->{Attributes}};

	my $path = $self->{path} .= '/' . $data->{LocalName};

	my $epdata = $self->{epdata};

	if ($path eq '/records/REC') {
		$self->{epdata} = {
				type => 'article',
			};
	}
	elsif ($path eq '/records/REC/UID') {
		$self->{characters} = \$epdata->{source};
	}
	elsif ($path eq '/records/REC/static_data/summary/titles/title') {
		my $type = $attr{type};
		if ($type eq 'item') {
			$self->{characters} = \$epdata->{title};
		}
		elsif ($type eq 'source') {
			$epdata->{ispublished} = "pub";
			$self->{characters} = \$epdata->{publication};
		}
	}
	elsif ($path =~ m{^/records/REC/static_data/fullrecord_metadata/abstracts/abstract/abstract_text\b}) {
		$self->{characters} = \$epdata->{abstract};
	}
	elsif ($path eq '/records/REC/dynamic_data/cluster_related/identifiers/identifier') {
		my $type = $attr{type};
		if ($type eq 'doi' || $type eq 'xref_doi') {
			$epdata->{id_number} = $attr{value};
		}
		elsif ($type eq 'issn') {
			$epdata->{issn} = $attr{value};
		}
	}
	elsif ($path eq '/records/REC/static_data/summary/pub_info/page') {
		$self->{characters} = \$epdata->{pagerange};
	}
	elsif ($path eq '/records/REC/static_data/summary/pub_info') {
		$epdata->{date_type} = 'published';
		$epdata->{date} = $attr{pubyear};
		$epdata->{date} .= $month_map{$attr{pubmonth}} if $attr{pubmonth};
		$epdata->{volume} = $attr{vol};
		$epdata->{number} = $attr{issue};
	}
	elsif ($path eq '/records/REC/static_data/summary/names/name') {
		my $role = $attr{role};
		my $person = $self->{person} = {};
		if ($role eq 'author') {
			push @{$epdata->{creators}}, $person;
		}
	}
	elsif ($path eq '/records/REC/static_data/summary/names/name/display_name') {
		$self->{characters} = \$self->{person}{name}{family};
	}
	elsif ($path eq '/records/REC/static_data/summary/names/name/email_addr') {
		$self->{characters} = \$self->{person}{id};
	}
	elsif ($path eq '/records/REC/static_data/fullrecord_metadata/fund_ack/grants/grant/grant_agency') {
		push @{$epdata->{funders}}, '';
		$self->{characters} = \$epdata->{funders}[-1];
	}
	elsif ($path eq '/records/REC/static_data/fullrecord_metadata/fund_ack/grants/grant/grant_ids/grant_id') {
		push @{$epdata->{projects}}, '';
		$self->{characters} = \$epdata->{projects}[-1];
	}
	elsif ($path =~ m{^/records/REC/static_data/fullrecord_metadata/fund_ack/fund_text\b}) {
		$self->{characters} = \$epdata->{note};
	}
	else {
		$self->{characters} = undef;
	}
}

sub end_element
{
	my ($self, $data) = @_;

	my $path = $self->{path};
	my $epdata = $self->{epdata};

	if ($path eq '/records/REC') {
		$self->{epdata_to_dataobj}(delete $self->{epdata});
	}
	elsif ($path eq '/records/REC/static_data/summary/names/name/display_name') {
		@{$self->{person}{name}}{qw(family given)}
			= split /,\s*/, $self->{person}{name}{family}, 2;
	}

	$self->{path} =~ s{/[^/]+$}{};
	$self->{characters} = undef;
}

sub characters
{
	my ($self, $data) = @_;

	${$self->{characters}} .= $data->{Data} if defined $self->{characters};
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

