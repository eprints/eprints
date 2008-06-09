package EPrints::Plugin::Export::Ids;

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Object IDs";
	$self->{accept} = [ 'list/*' ];
	$self->{visible} = "all";
	$self->{suffix} = ".txt";
	$self->{mimetype} = "text/plain; charset=utf-8";
	
	return $self;
}


sub output_list
{
	my( $plugin, %opts ) = @_;

	if( defined $opts{fh} )
	{
		print {$opts{fh}} join( "\n", @{$opts{list}->get_ids} )."\n";
		return;
	}

	return join( "\n", @{$opts{list}->get_ids} )."\n";
}

1;
