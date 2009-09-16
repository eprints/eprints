use strict;
use Test::More tests => 12;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }
BEGIN { use_ok( "EPrints::ScreenProcessor" ); }

my $session = EPrints::Test::get_test_session();

# find an example eprint
my $dataset = $session->get_repository->get_dataset( "eprint" );
my( $eprintid ) = @{ $dataset->get_item_ids( $session ) };

$session = EPrints::Test::OnlineSession->new( $session, {
	method => "GET",
	path => "/cgi/users/home",
	username => "admin",
	query => {
		screen => "EPrint::Staff::Edit",
		eprintid => $eprintid,
	},
});

my $processor = EPrints::ScreenProcessor->new(
	session => $session,
	url => $session->get_repository->get_conf( "base_url" ) . "/cgi/users/home",
	screenid => "!!!test!!!",
	);

my $screen = EPrints::Plugin::Screen->new(
	processor => $processor,
	);

$screen->properties_from();

is( $processor->{user}, $session->current_user, "properties_from()" );

my @items = $screen->list_items( "key_tools" );

BAIL_OUT("list_items didn't return anything for key_tools")
	unless scalar @items;

BAIL_OUT("list_items returned something weird")
	unless ref($items[0]) eq "HASH";

my $screen_id = "Screen::Items";

my( $items_screen ) = grep { $_->{screen_id} eq $screen_id } @items;

ok( defined $items_screen, "key_tools contains $screen_id" );

ok( defined($items_screen->{screen}) && $items_screen->{screen}->isa( "EPrints::Plugin::Screen" ), "item contains screen plugin" );

is( defined($items_screen->{screen_id}) && $items_screen->{screen_id}, $screen_id, "item contains screen_id" );

# disable
{
	local $session->get_repository->{config}->{plugins}->{$screen_id}->{appears}->{"key_tools"} = undef;

	my( $t ) = grep { $_->{screen_id} eq $screen_id } $screen->list_items( "key_tools" );

	ok( !defined($t), "disabled $screen_id" );
}

@items = $screen->action_list( "item_tools" );

$screen_id = "Screen::NewEPrint";

my( $ne_screen ) = grep { $_->{screen_id} eq $screen_id } @items;

ok( defined($ne_screen), "item_tools contains $screen_id" );

# disable action
{
	local $session->get_repository->{config}->{plugins}->{$screen_id}->{appears}->{"item_tools"} = undef;

	my( $t ) = grep { $_->{screen_id} eq $screen_id } $screen->action_list( "item_tools" );

	ok( !defined($t), "disabled $screen_id action" );
}

# configure to an unusual location
{
	# note we also check based on definedness, not trueness
	local $session->get_repository->{config}->{plugins}->{$screen_id}->{appears}->{"__TEST__"} = 0;

	my( $t ) = grep { $_->{screen_id} eq $screen_id } $screen->action_list( "__TEST__" );

	ok( defined($t), "enabled $screen_id in __TEST__ list" );
}

$session->terminate;

ok(1);
