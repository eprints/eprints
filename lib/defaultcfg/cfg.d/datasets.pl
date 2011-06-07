if( !defined $c->{datasets} )
{
	$c->{datasets} = {};
}

# Example custom datasets:
#
# The following dataset is an absolutely minimal dataset that still stores
# data.
#
# $c->{datasets}->{comment} = {
# 	class => "EPrints::DataObj",
# 	sqlname => "comment",
# 	datestamp => "datestamp",
# };
#
# And some fields:
#
# $c->{fields}->{comment} = [
# 	{
# 		name => "commentid",
# 		type => "counter",
# 		sql_counter => "commentid",
# 	},
# 	{
# 		name => "datestamp",
# 		type => "time",
# 	},
# 	{
# 		name => "title",
# 		type => "text",
# 	},
# 	{
# 		name => "body",
# 		type => "text",
# 	},
# ];
#
# The following dataset uses a custom class defined here.
#
# $c->{datasets}->{foo} = {
# 	name => "foo", # name
# 	type => "LocalFoo", # data object class
# 	sqlname => "foo", # database table name
# };
#
# See EPrints::DataSet for documentation on dataset properties.
#
# You probably want to define the data object class in a separate file
# (but it must be in your Perl path).
# You could define the class object in a cfg.d file but you *must* enclose
# the entire package in a enclosure, or you will break EPrints.
#
# {
#
# package EPrints::DataObj::LocalFoo;
#
# our @ISA = qw( EPrints::DataObj );
#
# sub get_system_field_info
# {
#	my( $class ) = @_;
#
#	return
#	(
#		{ name=>"fooid", type=>"counter", required=>1, can_clone=>0,
#			sql_counter=>"fooid" },
#		{ name=>"name", type=>"text", required=>0, },
#		{ name=>"version", type=>"text", required=>0, },
#		{ name=>"mime_type", type=>"text", required=>0, },
#	);
# }
#
# } ### end of package ###
