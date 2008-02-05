package EPrints::Plugin::Export::COinS;

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use URI::OpenURL;

use strict;

our %TYPES = (
	article => {
		namespace => "info:ofi/fmt:kev:mtx:journal",
		plugin => "Export::ContextObject::Journal",
	},
	book => {
		namespace => "info:ofi/fmt:kev:mtx:book",
		plugin => "Export::ContextObject::Book"
	},
	book_section => {
		namespace => "info:ofi/fmt:kev:mtx:book",
		plugin => "Export::ContextObject::Book"
	},
	conference_item => {
		namespace => "info:ofi/fmt:kev:mtx:book",
		plugin => "Export::ContextObject::Book",
	},
	thesis => {
		namespace => "info:ofi/fmt:kev:mtx:dissertation",
		plugin => "Export::ContextObject::Dissertation",
	},
	other => {
		namespace => "info:ofi/fmt:kev:mtx:dc",
		plugin => "Export::ContextObject::DublinCore",
	},
);

sub new
{
	my( $class, %opts ) = @_;

	my( $self ) = $class->SUPER::new( %opts );

	$self->{name} = "OpenURL ContextObject in Span";
	$self->{accept} = [ 'dataobj/eprint' ];
	$self->{visible} = "all";
	$self->{suffix} = ".txt";
	$self->{mimetype} = "text/plain";

	return $self;
}

sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $dataset = $dataobj->get_dataset;

	my $s = URI::OpenURL->new("");

	my $type = $dataobj->get_value( "type" );
	$type = "other" unless exists $TYPES{$type};

	my $rft_plugin = $TYPES{$type}->{plugin};
	$rft_plugin = $plugin->{session}->plugin( $rft_plugin );

	if( $dataset->has_field( "id_number" ) && $dataobj->is_set( "id_number" ) )
	{
		$s->referent( id => $dataobj->get_value( "id_number" ) );
	}

	$rft_plugin->kev_dataobj( $dataobj, scalar($s->referent) );

	return "$s";
}

1;
