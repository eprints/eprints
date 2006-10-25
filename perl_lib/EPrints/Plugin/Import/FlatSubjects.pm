
package EPrints::Plugin::Import::FlatSubjects;

use strict;

our @ISA = qw/ EPrints::Plugin::Import /;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Flat Subjects";
	$self->{visible} = "all";
	$self->{produce} = [ 'list/subject' ];

	return $self;
}

sub input_list
{
	my( $plugin, %opts ) = @_;

	my @ids = ();
	while( my $input_data = readline($opts{fh}) ) 
	{
		my $epdata = $plugin->convert_input( $input_data );

		next unless( defined $epdata );
		
		my $dataobj = $plugin->epdata_to_dataobj( $opts{dataset}, $epdata );
		if( defined $dataobj )
		{
			push @ids, $dataobj->get_id;
		}
	}
	
	return EPrints::List->new( 
		dataset => $opts{dataset}, 
		session => $plugin->{session},
		ids=>\@ids );
}

sub convert_input 
{
	my ( $plugin, $input_data ) = @_;

	chomp($input_data);

	return if $input_data =~ m/^\s*(#|$)/;
	my @vals = split /:/ , $input_data;

	my @parents = split( ",", $vals[2] );

	my $lang = $plugin->{session}->get_repository->get_conf( "defaultlanguage" );

	my $epdata = {
			subjectid   => $vals[0],
			name        => {$lang=>$vals[1]},
			parents     => \@parents,					
		        depositable => $vals[3],
		 };

	return $epdata;
}

1;
