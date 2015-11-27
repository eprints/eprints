=head1 NAME

EPrints::Plugin::Import::ISIWoK

=cut

package EPrints::Plugin::Import::ISIWoK;

use base qw( EPrints::Plugin::Import::ISIWoKXML );
use EPrints::Plugin::Import::TextFile;

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );


	$self->{name} = "ISI Web of Knowledge";
	$self->{advertise} = 1;
	$self->{visible} = "all";
	$self->{produce} = [ 'list/eprint' ];
	$self->{screen} = "Import::ISIWoK";
	$self->{arguments}{fields} = [];



	if( !EPrints::Utils::require_if_exists( "SOAP::ISIWoK", "3.00" ) )
	{
		$self->{visible} = 0;
		$self->{error} = "Requires SOAP::ISIWoK 3.00";
	}
	else
	{
		EPrints::Utils::require_if_exists( "SOAP::ISIWoK::Lite" );
	}

	return $self;
}

sub input_fh
{
	my ($self, %opts) = @_;
	return $self->EPrints::Plugin::Import::TextFile::input_fh( %opts );
}

sub input_text_fh
{
	my( $self, %opts ) = @_;

	if ($opts{fields})
	{
		$opts{fields} = [split /\s*,\s*/, $opts{fields}]
			if ref($opts{fields}) ne 'ARRAY';
	}

	my $session = $self->{session};

	my @ids;

	my $fh = $opts{fh};
	my $query = join '', <$fh>;

	my $wok = $self->param('lite') ?
		SOAP::ISIWoK::Lite->new :
		SOAP::ISIWoK->new;
	my $som = $wok->authenticate($self->param('username'), $self->param('password'));
	if ($som->fault)
	{
		if ($som->faultstring =~ /Throttle server/)
		{
			print STDERR "Request denied by Throttle server\n";
		}
		else
		{
			print STDERR $som->faultstring,"\n";
		}
#		$self->warning($som->faultstring);
		return undef;
	}
	$som = $wok->search( $query,
		offset => $opts{offset},
		fields => $opts{fields},
	);
	if ($som->fault)
	{
#		$self->error($som->faultstring);
		print STDERR "Query Failed", $som->faultstring,"\n";
		return EPrints::List->new(
				session => $session,
				dataset => $opts{dataset},
				ids => []
			);
	}
	$self->{total} = $som->result->{recordsFound};
	if ($self->param('lite'))
	{
		my @ids;
#https://github.com/eprints/eprints/commit/da2695a8aa7b8a32fdf81d00f7353f3e7c827ccb  bug fix
		my $records = $som->result->{records};
		$records = [$records] unless ref($records) eq 'ARRAY';
		foreach my $record (@$records)
		{
			my $epdata = $self->isidata_to_epdata($record, %opts);
			my $dataobj = $self->epdata_to_dataobj($epdata, %opts);
			push @ids, $dataobj->id if defined $dataobj;
		}
		return EPrints::List->new(
				session => $session,
				dataset => $opts{dataset},
				ids => \@ids
			);
	}
	else
	{
		open(my $xml_fh, "<", \$som->result->{records}) or die "Error getting fh to scalar: $!";

		return $self->SUPER::input_fh(
			%opts,
			fh => $xml_fh,
		);
	}
}

=item $epdata = isidata_to_epdata($data)

The Lite service returns a completely different structure to the Premium service.

This method will convert the Lite service data structure into epdata.

=cut

sub isidata_to_epdata
{
	my ($self, $data, %opts) = @_;

	my $epdata = {
			type => "article",
		};

	if (ref($data->{authors}) ne 'ARRAY')
	{
		$data->{authors} = [$data->{authors}];
	}
	foreach my $authors (@{$data->{authors}})
	{
		next if $authors->{label} ne 'Authors';
		if (ref($authors->{value}) ne 'ARRAY')
		{
			$authors->{value} = [$authors->{value}]
		}
		foreach my $name (@{$authors->{value}})
		{
			my ($family, $given) = split /\s*,\s/, $name;
			push @{$epdata->{creators}}, {
				name => {
					family => $family,
					given => $given,
				},
			};
		}
	}

	if (ref($data->{source}) ne 'ARRAY')
	{
		$data->{source} = [$data->{source}];
	}
	if (ref($data->{other}) ne 'ARRAY')
	{
		$data->{other} = [$data->{other}];
	}
	foreach my $part (@{$data->{source}||[]}, @{$data->{other}||[]})
	{
		my( $label, $value ) = @$part{qw( label value )};
		if ($label eq 'Issue') {
			$epdata->{number} = $value;
		}
		elsif ($label eq 'Pages') {
			$epdata->{pagerange} = $value;
		}
		elsif ($label eq 'SourceTitle') {
			$epdata->{ispublished} = "pub";
			$epdata->{publication} = $value;
		}
		elsif ($label eq 'Volume') {
			$epdata->{volume} = $value;
		}
		elsif ($label eq 'Published.BiblioYear') {
			$epdata->{date_type} = 'published';
			$epdata->{date} = $value;
		}
		elsif ($label eq 'Identifier.Issn') {
			$epdata->{issn} = $value;
		}
		elsif ($label eq 'Identifier.Xref_Doi') {
			$epdata->{id_number} = $value;
		}
	}

	$epdata->{source} = $data->{uid};

	$epdata->{title} = $data->{title}{value};

	return $epdata;
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

