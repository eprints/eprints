package EPrints::Plugin::Export::Subject;

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Subjects file";
	$self->{accept} = [ 'dataobj/subject', 'list/subject' ];
	$self->{visible} = "all";
	$self->{suffix} = ".txt";
	$self->{mimetype} = "text/plain; charset=utf-8";
	
	return $self;
}

sub output_dataobj
{
	my( $self, $dataobj ) = @_;

	my @parts;

	push @parts, $dataobj->get_id;
	my $names = $dataobj->get_value( "name_name" );
	if( EPrints::Utils::is_set( $names ) )
	{
		push @parts, $names->[0];
	}
	else
	{
		push @parts, "";
	}
	my $parents = $dataobj->get_value( "parents" );
	push @parts, join ",", @$parents;
	push @parts, $dataobj->get_value( "depositable" ) ? "1" : "0";

	return join(":", @parts)."\n";
}

1;
