package EPrints::Plugin::Export::MultilineCSV;

use EPrints::Plugin::Export;
use EPrints::Plugin::Export::Grid;

@ISA = ( "EPrints::Plugin::Export::Grid" );

use strict;

use Data::Dumper;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Multiline CSV";
	$self->{accept} = [ 'dataobj/eprint', 'list/eprint', ];
	$self->{visible} = "staff";
	$self->{suffix} = ".csv";
	$self->{mimetype} = "text/csv";
	
	return $self;
}


sub output_list
{
	my( $plugin, %opts ) = @_;

	my $part = csv( $plugin->header_row( %opts ) );

	my $r = [];

	if( defined $opts{fh} )
	{
		print {$opts{fh}} $part;
	}
	else
	{
		push @{$r}, $part;
	}


	# list of things

	$opts{list}->map( sub {
		my( $handle, $dataset, $item ) = @_;

		my $part = $plugin->output_dataobj( $item, %opts );
		if( defined $opts{fh} )
		{
			print {$opts{fh}} $part;
		}
		else
		{
			push @{$r}, $part;
		}
	} );

	return if( defined $opts{fh} );

	return join( '', @{$r} );
}

sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $rows = $plugin->dataobj_to_rows( $dataobj );

	my $r = [];
	for( my $row_n=0;$row_n<scalar @{$rows};++$row_n  )
	{
		my $row = $rows->[$row_n];
		push @{$r}, csv( @{$row} );
	}

	return join( "", @{$r} );
}

sub csv
{
	my( @row ) = @_;

	my @r = ();
	foreach my $item ( @row )
	{
		if( !defined $item )
		{
			push @r, "";
			next;
		}
		$item =~ s/(["\\])/\\$1/g;
		push @r, '"'.$item.'"';
	}
	return join( ",", @r )."\n";
}

1;
