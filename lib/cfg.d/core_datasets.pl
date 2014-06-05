#
# sf2 - COMMENTS on Datasets 
#
# 1- Datasets do not -really- need to supply their own DataObj::XYZ class: it will work by using the ISA EPrints::DataObj (not true in EPrints3)
# 2- counter fields do not need to supply a 'sql_name' anymore - the name of the field (eg 'movieid') is used by default
#
# sf2 - THINGS UNDER CONSIDERATION
#
# 1- being able to define certain properties for datasets which will enable some fields/behaviours automatically
#
#	1-a "flow" => { initial_state => SCALAR, flow => HASH } (default: UNDEF) to replace eprint_status and alikes
#	1-b "revision" => true or false (1,0) (default: true) - increments each time an object is modified/committed to the DB (useful for e.g. ETag's) <IMPLEMENTED>
#	1-c "acl" => true or false (1,0) (default: false) - enable permission/control-list to access that dataset (read,write,update.....)
#	1-d "cache" ? => true or false (1,0) (default: true) - enable memcached (if enabled globally) for that dataset (TODO)
#	1-e "read-only" => true or false (1,0) (default: false) - makes that dataset read-only (disables set_value/commit/update/...) <IMPLEMENTED>
#	1-f "history" => true or false (1,0) (default: false) - keeps a history of changes for the objects of the dataset - implies "revision" => true
#	1-g "lastmod" => true or false (1,0) (default: true) - keeps a timestamp of when a dataobj was last modified
#	1-h "datestamp" => true or false - similar as above, timestamp of creation of object
#	1-i "loghandler" => save 'access'/download stats (TODO)
#
#	^^ the point of all of this is to allow consistent automatic behaviours/options which can be tested/implemented globally e.g. $self->dataset->property( 'lastmod' ) etc

$c->{datasets} = {
	event_queue => {
		class => "EPrints::DataObj::EventQueue",
		datestamp => 1,
		columns => [qw( status start_time pluginid action params )],
	},
	file => {
		class => "EPrints::DataObj::File",
		datestamp => 1,
		lastmod => 1,
	},
	thumbnail => {
		class => "EPrints::DataObj::Thumbnail",
		datestamp => 1,
		lastmod => 1,
		revision => 0,
	},
	cachemap => {
		class => "EPrints::DataObj::Cachemap",
		revision => 0,
		lastmod => 0,
	},
	loginticket => {
		class => "EPrints::DataObj::LoginTicket",
		revision => 0,
		lastmod => 0,
	},
	counter => {
		sqlname => "counters",
		virtual => 1,
	},
	user => {
		class => "EPrints::DataObj::User",
		import => 1,
		revision => 1,
		lastmod => 1,
		datestamp => 1,
		history => 1,
	},
	subject => {
		class => "EPrints::DataObj::Subject",
		import => 1,
		datestamp => 0,
	},
	triple => {
		class => "EPrints::DataObj::Triple",
		import => 1,
		datestamp => 0,
		lastmod => 0,
		revision => 0,
	},
	epm => {
		class => "EPrints::DataObj::EPM",
		virtual => 1,
	},
	acl => {
		class => "EPrints::DataObj::ACL",
		revision => 0,
		datestamp => 0,
		lastmod => 0,
		history => 0
	},
	import => {
		class => "EPrints::DataObj::Import",
		revision => 0,
		datestamp => 1,
		lastmod => 1,
		history => 0,
	},
	history => {
		class => "EPrints::DataObj::History",
		revision => 0,
		datestamp => 1,
		history => 0,		# don't keep history of history!
	},
};

$c->{datasets}->{user}->{contexts} = {

		"own-record" => {
			# search filters - shouldn't this also be allowed to return a STOP value? to stop/cancel the search TODO
			get_filters => sub {
				my( $repo ) = @_;
				return [ { meta_fields => [qw/ userid /], value => $repo->current_user->id, match => 'EX' } ];
			},
			
			# matches
			matches => sub {
				my( $repo, $dataobj ) = @_;
				return $repo->current_user->value( 'userid' ) eq $dataobj->value( 'userid' );
			},
		},
};

