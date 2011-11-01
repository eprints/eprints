#!/usr/bin/perl

use Test::More tests => 4;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

my $repository = EPrints::Test::get_test_repository();
my $session = EPrints::Test::get_test_session();
my $dataset = $session->get_repository->get_dataset( "archive" );

my $plugin;

SKIP: {
	$plugin = $session->plugin( "Import::BibTeX" );
	skip "missing Import::BibTeX", 1 unless defined $plugin;

my $bibtex = <<'EOB';
@Article{Ahrenberg88,
	author =       {L. von Ahrenberg~Poussin and J{\"o}nsson, Jr., A. and P. O'Reilly},
	title =        {An interactive system for tagging dialogues },
	journal =      "Literary \& Linguistic Computing",
	volume =       "3",
	number =       "2",
	pages =        "66--70",
	year =         "1988",
	keywords =     "conver",
}
EOB

	my $handler = EPrints::CLIProcessor->new(
		session => $session,
		epdata_to_dataobj => sub {
			my( $epdata ) = @_;

			is($epdata->{volume}, "3", "bibtext import volume");

			undef;
		},
	);

	$plugin->set_handler( $handler );
	open(my $fh, "<", \$bibtex) or die "Can't open string as file handle: $!";
	my $list = $plugin->input_fh(
		fh => $fh,
		dataset => $session->dataset( "archive" ),
	);
};

$session->cache_subjects;

my @records = $dataset->search( allow_empty => 1 )->slice( 0, 50 );

$plugin = $session->plugin( "Export::DC" );
for(@records)
{
	$plugin->convert_dataobj( $_ );
}

{
	my $class = "EPrints::Plugin::Export::LocalDC";
	eval <<"EOP";
package $class;

\@${class}::ISA = qw( EPrints::Plugin::Export::DC );

1;
EOP

	my $pf = $session->get_plugin_factory;
	$pf->register_plugin(
		$pf->{repository_data},
		$class->new( session => $session )
	);
	my $conf = $session->{config};
	local $conf->{plugins}->{"Export::DC"}->{params}->{disable} = 1;
	local $pf->{alias}->{"Export::DC"} = substr($class, 17);
	local $pf->{alias}->{substr($class, 17)} = undef;

	my $plugin = $session->plugin( "Export::DC" );
	is( ref($plugin), $class, "plugin_alias_map" );
}
