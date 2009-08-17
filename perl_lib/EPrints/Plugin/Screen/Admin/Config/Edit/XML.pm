package EPrints::Plugin::Screen::Admin::Config::Edit::XML;

use EPrints::Plugin::Screen::Admin::Config::Edit;

@ISA = ( 'EPrints::Plugin::Screen::Admin::Config::Edit' );

use strict;

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "config/edit/xml" );
}

sub validate_config_file
{
	my( $self, $data ) = @_;

	my @issues = $self->SUPER::validate_config_file( $data );

	my $tmpfile = "/tmp/tmp_ep_config_file.$$";
	open( TMP, ">$tmpfile" );
	print TMP $data;
	close TMP;
	eval {
		my $doc = EPrints::XML::parse_xml( 
			$tmpfile, 
			$self->{handle}->get_repository->get_conf( "variables_path" )."/",
			1 );
	};
	my $xml_parse_issues = $@;
	unlink( $tmpfile );
	if( $xml_parse_issues )
	{
		my $pre = $self->{handle}->make_element( "pre" );
		$pre->appendChild( $self->{handle}->make_text( $xml_parse_issues ) );
		push @issues, $pre;
	}

	return @issues;
}

1;
