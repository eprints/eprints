

#cjg headers?


# This modules contains stuff
# common to this installation of eprints.

package EPrints::Site::General;

use Unicode::String qw(utf8 latin1 utf16);

$EPrints::Site::General::base_path = "/opt/eprints";

$EPrints::Site::General::log_language = "english";

$EPrints::Site::General::lang_path = 
	$EPrints::Site::General::base_path."/intl";

%EPrints::Site::General::languages = (
	"dummy" => latin1( "Demonstration Other Language" ),
	"french" => latin1( "Français" ),
	"english" => latin1( "English" )
);


#English Español Deutsch Français Italiano

%EPrints::Site::General::sites = (
	"destiny.totl.net" => "lemurprints",
	"destiny" => "lemurprints",
	"lemur.ecs.soton.ac.uk" => "lemurprints",
	"localhost" => "lemurprints"
);





1;
