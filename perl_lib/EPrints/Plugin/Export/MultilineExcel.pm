package EPrints::Plugin::Export::MultilineExcel;

use Unicode::String qw( utf8 );

use EPrints::Plugin::Export;
use EPrints::Plugin::Export::Grid;

@ISA = ( "EPrints::Plugin::Export::Grid" );

use strict;

use Data::Dumper;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Multiline Execl";
	$self->{accept} = [ 'list/eprint' ];
	$self->{visible} = "staff";
	$self->{suffix} = ".xls";
	$self->{mimetype} = 'application/vnd.ms-excel';

	my $rc = EPrints::Utils::require_if_exists('Spreadsheet::WriteExcel');
	unless ($rc)
	{
		$self->{visible} = '';
		$self->{error} = 'Unable to load required module Spreadsheet::WriteExcel';
	}
	
	return $self;
}

sub output_list
{
	my( $plugin, %opts ) = @_;

	my $output;
	open(my $FH,'>',\$output);

	my $workbook;
	if (defined $opts{fh})
	{
		binmode($opts{fh});
		$workbook = Spreadsheet::WriteExcel->new(\*{$opts{fh}});
		die("Unable to create spreadsheet: $!")unless defined $workbook;
	}
	else
	{
		$workbook = Spreadsheet::WriteExcel->new($FH);
		die("Unable to create spreadsheet: $!")unless defined $workbook;
	}

	my $worksheet = $workbook->add_worksheet();

	my $col_id = 0;
	my @cols = $plugin->header_row( %opts );
	foreach my $col (@cols)
	{
		$worksheet->write( 0, $col_id, $col );
		++$col_id;
	}

	my $row_id = 1;

	$opts{list}->map( sub {
		my( $session, $dataset, $item ) = @_;

		my $rows = $plugin->dataobj_to_rows( $item );
	
		foreach my $row ( @{$rows} )
		{
			my $col_id = 0;
			foreach my $col (@{$row})
			{
				$worksheet->write( $row_id, $col_id, $col );
				++$col_id;
			}
			++$row_id;
		}
	} );

	$workbook->close;

	if (defined $opts{fh})
	{
		return undef;
	}

	return $output;
}


1;
