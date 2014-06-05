
$c->{datasets} = {
	event_queue => {
		sqlname => "event_queue",
		class => "EPrints::DataObj::EventQueue",
		datestamp => "start_time",
		columns => [qw( status start_time pluginid action params )],
	},
	file => {
		sqlname => "file",
		class => "EPrints::DataObj::File",
		datestamp => "lastmod",
	},
	thumbnail => {
		sqlname => "thumbnail",
		class => "EPrints::DataObj::Thumbnail",
		datestamp => "lastmod",
	},
	cachemap => {
		sqlname => "cachemap",
		class => "EPrints::DataObj::Cachemap",
		revision => 0,
		lastmod => 0,
	},
	loginticket => {
		sqlname => "loginticket",
		class => "EPrints::DataObj::LoginTicket",
		revision => 0,
		lastmod => 0,
	},
	counter => {
		sqlname => "counters",
		virtual => 1,
	},
#	user => {
#		sqlname => "user",
#		class => "EPrints::DataObj::User",
#		import => 1,
#		datestamp => "joined",
#	},
	subject => {
		sqlname => "subject",
		class => "EPrints::DataObj::Subject",
		import => 1,
	},
	triple => {
		sqlname => "triple",
		class => "EPrints::DataObj::Triple",
		import => 1,
	},
	epm => {
		sqlname => "epm",
		class => "EPrints::DataObj::EPM",
		virtual => 1,
	},
	acl => {
		sqlname => "acl",
		class => "EPrints::DataObj::ACL",
		revision => 0,
		datestamp => 0,
		lastmod => 0,
		history => 0
	},
	import => {
		sqlname => "import",
		class => "EPrints::DataObj::Import",
		revision => 0,
		datestamp => 1,
		lastmod => 1,
		history => 0,
	},
	history => {
		sqlname => "history",
		class => "EPrints::DataObj::History",
		revision => 0,
		datestamp => 1,
		history => 0,		# don't keep history of history!
	},
};

