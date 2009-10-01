#!/usr/bin/perl

use Test::More tests => 6;

use strict;
use warnings;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

# These methods are defined in the API and should exist
my %API_METHODS = (
	"EPrints" => [qw( new abort current_repository repository repository_ids )],
	"EPrints::Repository" => [qw( config current_url current_user dataset eprint log redirect query user user_by_email user_by_username xhtml xml )],
	"EPrints::Dataset" => [qw( base_id create_dataobj dataobj field fields key_field id list prepare_search search )],
	"EPrints::List" => [qw( count ids item map slice )],
	"EPrints::XML" => [qw( clone clone_node contents_of create_comment_node create_document_fragment create_element create_text_node dispose parse_file parse_string parse_url text_contents_of to_string )],
	"EPrints::XHTML" => [qw( build_page form hidden_field input_field text_area_field to_xhtml )],
	"EPrints::Page" => [qw( send write_to_file )],
	"EPrints::DataObj" => [qw( commit create_subobject dataobj delete export id is_set render_citation render_value set_value uri url value )],
	"EPrints::MetaField" => [qw( name property render_help render_name render_value_label set_property sort_values type values )],
);

my $repoid = EPrints::Test::get_test_id();

my $ep = EPrints->new();
isa_ok( $ep, "EPrints", "EPrints->new()" );
if( !defined $ep ) { BAIL_OUT( "Could not obtain the EPrints System object" ); }

is( $ep->repository( "badrepoid" ), undef, "Bad repository ID returns undef" );

my $repo = $ep->repository( $repoid );
isa_ok( $repo, "EPrints::Repository", "Get a repository object ($repoid)" );
if( !defined $repo ) { BAIL_OUT( "Could not obtain the Repository object" ); }

# No test for:
#
# $repo = $ep->current_repository(); # from Apache::Request URI
#
# EPrints->abort( $message );

# Check all of the defined API methods are available
my @missing;
foreach my $class (sort keys %API_METHODS)
{
	foreach my $method (sort @{$API_METHODS{$class}})
	{
		my $name = "${class}::${method}";
		if( !defined &$name )
		{
			push @missing, $name;
		}
	}
}
if( @missing )
{
	diag("Missing following API methods: ".join(', ', @missing));
}
ok(@missing==0, "all API methods defined");
