=head1 NAME

EPrints::Plugin::Export::MultilineExcel

=cut

package EPrints::Plugin::Export::MultilineExcel;

use EPrints::Plugin::Export;
use EPrints::Plugin::Export::Grid;

@ISA = ( "EPrints::Plugin::Export::Grid" );

use strict;

use Data::Dumper;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Multiline Excel";
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

	$workbook->set_properties( utf8 => 1 );

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

