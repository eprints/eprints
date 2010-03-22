package EPrints::Plugin::Export::SummaryPage;

use EPrints::Plugin::Export::HTMLFile;

@ISA = ( "EPrints::Plugin::Export::HTMLFile" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my( $self ) = $class->SUPER::new( %opts );

	$self->{name} = "Summary Page";
	$self->{accept} = [ 'dataobj/*' ];
	$self->{visible} = "all";
	$self->{advertise} = 0;
	$self->{qs} = 0.9;

	return $self;
}

sub output_dataobj
{
	my( $self, $dataobj, %opts ) = @_;

	my $repo = $self->{session};

	return "" if !$repo->get_online;

	my $title = $dataobj->render_citation( "summary_title" );
	my $page = $dataobj->render_citation( "summary_page" );
	$repo->build_page( $title, $page, "export" );
	$repo->send_page;

	return "";
}

1;
