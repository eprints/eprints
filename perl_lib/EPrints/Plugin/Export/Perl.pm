package EPrints::Plugin::Export::Perl;

use Data::Dumper;

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Perl data structure";
	$self->{accept} = [ 'list/metafield', 'dataobj/metafield' ];
	$self->{visible} = "all";
	$self->{suffix} = ".pl";
	$self->{mimetype} = "text/plain";
	
	return $self;
}

sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $dumper = Data::Dumper->new( [$dataobj->get_perl_struct] );
	$dumper->Terse(1);

	return $dumper->Dump;
}

sub output_list
{
	my( $plugin, %opts ) = @_;

	my %datasets;

	$opts{list}->map( sub {
		my( $handle, $dataset, $item ) = @_;

		my $datasetid = $item->get_value( "mfdatasetid" );
		push @{$datasets{$datasetid}}, $plugin->output_dataobj( $item );
	} );

	my $r = "";

	foreach my $datasetid (keys %datasets)
	{
		$r .= "push \@{\$c->{fields}->{$datasetid}}, (\n";
		$r .= join "", map { chomp($_); "\t$_,\n" } @{$datasets{$datasetid}};
		$r .= ");\n\n";
	}

	if( defined $opts{fh} )
	{
		print {$opts{fh}} $r;
	}
	else
	{
		return $r;
	}
}

1;
