use lib '/opt/eprints3/perl_lib';

# this script is deprecated and is included here to support legacy Apache
# configurations

use EPrints;

&EPrints::post_config_handler(
	undef, # conf_pool
	undef, # log_pool
	undef, # temp_pool
	Apache2::ServerUtil->server
);

1;
