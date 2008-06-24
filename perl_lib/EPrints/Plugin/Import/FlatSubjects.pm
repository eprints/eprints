
package EPrints::Plugin::Import::FlatSubjects;

use EPrints::Plugin::Import::TextFile;
use strict;

our @ISA = qw/ EPrints::Plugin::Import::TextFile /;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Flat Subjects";
	$self->{visible} = "all";
	$self->{produce} = [ 'list/subject' ];

	return $self;
}

sub input_text_fh
{
	my( $plugin, %opts ) = @_;

	my $fh = $opts{fh};

	my @ids = ();
	my $input_data;
	while( defined($input_data = <$fh>) ) 
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

	return if $input_data =~ m/^\s*(#|$)/;
	chomp $input_data;
	my @vals = split /:/ , $input_data;

	my @parents = split( ",", $vals[2] );

	my $lang = $plugin->{session}->get_repository->get_conf( "defaultlanguage" );

	my $epdata = {
			subjectid   => $vals[0],
			name_name   => [$vals[1]],
			name_lang   => [$lang],
			parents     => \@parents,					
		        depositable => ($vals[3]?"TRUE":"FALSE"),
		 };
	return $epdata;
}

1;
