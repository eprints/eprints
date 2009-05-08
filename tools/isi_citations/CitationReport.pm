package EPrints::Plugin::Export::CitationReport;

use strict;
use warnings;

our @ISA = qw( EPrints::Plugin::Export );

sub new
{
	my( $class, %opts ) = @_;

	my( $self ) = $class->SUPER::new( %opts );

	$self->{name} = "Citation Report";
	$self->{accept} = [ 'list/eprint' ];
	$self->{visible} = "all";
	$self->{mimetype} = "text/plain; charset=utf-8";
	$self->{suffix} = ".csv";

	return $self;
}

sub output_list
{
	my( $self, %opts ) = @_;

	my $list = $opts{list};

	my %creators_data;

	$list->map(\&collate_by_creator, \%creators_data);

	my @headings = (
		'Name',
		'Key',
		'Number of Publications',
		'Number of Publications with ISI Count',
		'ISI Counts',
		'ISI Mean',
		'ISI H Index',
		'Number of Publications with Google Scholar Count',
		'Google Scholar Counts',
		'Google Scholar Mean',
		'Google Scholar H Index',
	);

	my $rows = $self->calculate_rows( \%creators_data );

	if( defined $opts{fh} )
	{
		binmode($opts{fh}, ":utf8");
		for(\@headings, @$rows)
		{
			print {$opts{fh}} render_row( @$_ );
		}
		return;
	}

	return join('', map { render_row( @$_ ) } (\@headings, @$rows ));
}

sub value
{
	my ($value) = @_;
	return $value if $value;
	return 0;
}

sub collate_by_creator
{
	my ($session, $dataset, $eprint, $creators_data ) = @_;

	my $creators = $eprint->get_value('creators');
	my $isi_citation_count = $dataset->has_field( "wos_impact" ) ?
		$eprint->get_value('wos_impact') :
		undef;
	my $gscholar_citation_count = $dataset->has_field( "gscholar_impact" ) ?
		$eprint->get_value('gscholar_impact') :
		undef;
	foreach my $creator (@{$creators})
	{
		my $id = $creator->{id};
		if( !defined $id or !length($id) )
		{
			$id = $dataset->get_field( "creators_name" )->get_id_from_value( $session, $creator->{name} );
		}
		next unless defined $id and $id ne "NULL";
		$id = fix_utf8($id);
		my $data = $creators_data->{$id} ||= {
				key => $id,
				pubs => 0,
				isi_pubs => [],
				gscholar_pubs => [],
			};
		if( !defined $data->{name} )
		{
			my $xml = $session->render_name( $creator->{name} );
			$data->{name} = fix_utf8(EPrints::Utils::tree_to_utf8($xml));
			EPrints::XML::dispose($xml);
		}
		$data->{pubs}++;
		if (defined $isi_citation_count)
		{
			push @{$data->{isi_pubs}}, $isi_citation_count;
		}
		if (defined $gscholar_citation_count)
		{
			push @{$data->{gscholar_pubs}}, $gscholar_citation_count;
		}
	}
}

sub calculate_rows
{
	my( $self, $data ) = @_;

	my @rows;

	while(my( $key, $record ) = each %$data)
	{
		my @row;
		push @row, $record->{name}, $record->{key}, $record->{pubs};
		my $isi_stats = $self->calculate_stats( $record->{isi_pubs} );
		push @row, @{$isi_stats}{qw( pubs sum mean hindex )};
		my $gs_stats = $self->calculate_stats( $record->{gscholar_pubs} );
		push @row, @{$gs_stats}{qw( pubs sum mean hindex )};
		push @rows, \@row;
	}

	return \@rows;
}

sub calculate_stats
{
	my( $self, $data ) = @_;

	@$data = sort { $b <=> $a } @$data;

	my $hindex = 0;
	my $sum = 0;

	for(my $i = 0; $i < @$data; ++$i)
	{
		++$hindex if $data->[$i] >= $i;
		$sum += $data->[$i];
	}

	return {
		pubs => scalar(@$data),
		hindex => $hindex,
		sum => $sum,
		mean => (@$data > 0 ? ($sum/scalar(@$data)) : 0),
	};
}

sub render_row
{
	return join(',', map { render_cell($_) } @_) . "\n";
}

sub render_cell
{
	my ($data) = @_;

	return "" unless defined $data;
	return $data unless $data =~ /[\n" ,]/;

	$data =~ s/"/""/g; #escape quotes

	return "\"$data\"";
}

# this is a hack to support 3.1/3.2
sub fix_utf8
{
	$_[0] = "$_[0]"; # stringify
	utf8::decode($_[0]);
	return $_[0];
}

1;
