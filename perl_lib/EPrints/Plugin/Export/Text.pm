package EPrints::Plugin::Export::Text;

use Unicode::String qw( utf8 );

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "ASCII Citation";
	$self->{accept} = [ 'dataobj/eprint', 'list/eprint' ];
	$self->{visible} = "all";
	$self->{suffix} = ".txt";
	$self->{mimetype} = "text/plain; charset=utf-8";
	
	return $self;
}


sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $cite = $dataobj->render_citation;

	return EPrints::Utils::tree_to_utf8( $cite )."\n\n";
}

1;
