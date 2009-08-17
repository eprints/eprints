package EPrints::Plugin::Import::MultilineExcel;

use strict;
use Data::Dumper;

our @ISA = qw/ EPrints::Plugin::Import /;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{name} = "Multiline Excel";
	$self->{visible} = "all";
	$self->{produce} = [ 'list/eprint' ];

	my $rc = EPrints::Utils::require_if_exists('Spreadsheet::ParseExcel');
	unless ($rc)
	{
		$self->{visible} = '';
		$self->{error} = 'Unable to load required module Spreadsheet::ParseExcel';
	}

	return $self;
}

sub input_file
{
	my( $plugin, %opts ) = @_;

	my $filename = $opts{filename};
	if( $filename eq '-' )
	{
		$filename = "/tmp/tmp.$$.xls";
		open( TMP, ">$filename" );
		print TMP <STDIN>;
		close TMP;
	}

	my $handle = $plugin->{handle};

	my $excel = Spreadsheet::ParseExcel::Workbook->Parse( $filename );

	if( $opts{filename} eq "-" )
	{
		unlink $filename;
	}

	my $sheet = $excel->{Worksheet}->[0];

	$sheet->{MaxRow} ||= $sheet->{MinRow};
	$sheet->{MaxCol} ||= $sheet->{MinCol};
	my $row_id = $sheet->{MinRow};

	my $colmap = [];
	if( $sheet->{Cells}[$sheet->{MinRow}][$sheet->{MinCol}]->{Val} ne "eprintid" )
	{
		$plugin->handler->message( "error", $handle->make_text( "Top left cell is not 'eprintid'" ));
		return;
	}
	foreach my $col ( $sheet->{MinCol}..$sheet->{MaxCol} )
	{
		my $cell = $sheet->{Cells}[$sheet->{MinRow}][$col];
		if( $cell ) 
		{
			$colmap->[$col] = $cell->{Val};
		}
	}

	my $by_eprint = {};

	foreach my $row ( $sheet->{MinRow}+1..$sheet->{MaxRow} )
	{
		my $data = {};
		foreach my $col ( $sheet->{MinCol}..$sheet->{MaxCol} )
		{
			my $cell = $sheet->{Cells}[$row][$col];
			if( $cell ) 
			{
				$data->{$colmap->[$col]} = $cell->{Val};
			}
		}

		$by_eprint->{$data->{eprintid}}->{$data->{rowid}} = $data;
	}

	my @ids = ();
	foreach my $eprintid ( keys %{$by_eprint} )
	{
		my $epdata = {};
		my $rowsdata = $by_eprint->{$eprintid};
		foreach my $row ( sort keys %{$rowsdata} )
		{
			my $rowdata = $rowsdata->{$row};
			my( undef, $row_n ) = split( /_/, $rowdata->{rowid} );
			foreach my $dataid ( keys %{$rowdata} )
			{
				next if $dataid eq "rowid";
				my( $fieldid, $part ) = split( /\./, $dataid );
				if( defined $part )
				{
					$epdata->{$fieldid}->[$row_n]->{$part} = $rowdata->{$dataid};
				}
				else
				{
					$epdata->{$fieldid}->[$row_n] = $rowdata->{$dataid};
				}
			}
		}

		foreach my $field ( $opts{dataset}->get_fields )
		{
			next if $field->get_property( "multiple" );
			if( defined $epdata->{$field->get_name} )
			{
				$epdata->{$field->get_name} = $epdata->{$field->get_name}->[0];
			}
		}
			
		print Dumper( $epdata );

		my $dataobj = $plugin->epdata_to_dataobj( $opts{dataset}, $epdata );
	}

	return EPrints::List->new( 
		dataset => $opts{dataset}, 
		handle => $plugin->{handle},
		ids=>\@ids );
}

1;
