=head1 NAME

EPrints::Plugin::Import::MultilineExcel

=cut

package EPrints::Plugin::Import::MultilineExcel;

use strict;

our @ISA = qw/ EPrints::Plugin::Import /;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{name} = "Multiline Excel";
	$self->{visible} = "all";
	$self->{produce} = [ 'list/eprint' ];
	$self->{advertise} = 0;

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

	my $session = $plugin->{session};

	my $filename = $opts{filename};
	if( $filename eq '-' )
	{
		$filename = "/tmp/tmp.$$.xls";
		open( TMP, ">$filename" );
		print TMP <STDIN>;
		close TMP;
	}
	elsif( !-r $opts{filename} )
	{
		$plugin->handler->message( "error", $session->make_text( "Cannot read from file: $opts{filename}" ));
		return;
	}

	my $excel = Spreadsheet::ParseExcel::Workbook->Parse( $filename );
	if( !defined $excel )
	{
		$plugin->handler->message( "error", $session->make_text( "Error parsing input, check it's an Excel spreadsheet file" ));
		return;
	}

	if( $opts{filename} eq "-" )
	{
		unlink $filename;
	}

	my $sheet = $excel->{Worksheet}->[0];

	$sheet->{MaxRow} ||= $sheet->{MinRow};
	$sheet->{MaxCol} ||= $sheet->{MinCol};
	my $row_id = $sheet->{MinRow};
	if( !defined($sheet->{MinRow}) )
	{
		$plugin->handler->message( "error", $session->make_text( "Error parsing input, empty or corrupted file" ));
		return;
	}

	my $colmap = [];
	if( $sheet->{Cells}[$sheet->{MinRow}][$sheet->{MinCol}]->{Val} ne "eprintid" )
	{
		$plugin->handler->message( "error", $session->make_text( "Top left cell is not 'eprintid'" ));
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
			
		my $dataobj = $plugin->epdata_to_dataobj( $opts{dataset}, $epdata );
	}

	return EPrints::List->new( 
		dataset => $opts{dataset}, 
		session => $plugin->{session},
		ids=>\@ids );
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

