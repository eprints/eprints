

#cjg headers?


# This modules contains stuff
# common to this installation of eprints.

package EPrints::Archives::General;

use Unicode::String qw(utf8 latin1 utf16);

$EPrints::Archives::General::base_path = "/opt/eprints";

$EPrints::Archives::General::lang_path = 
	$EPrints::Archives::General::base_path."/intl";

%EPrints::Archives::General::languages = (
	"dummy" => latin1( "Demonstration Other Language" ),
	"french" => latin1( "Français" ),
	"english" => latin1( "English" )
);


#English Español Deutsch Français Italiano

%EPrints::Archives::General::sites = (
	"destiny.totl.net" => "lemurprints",
	"destiny" => "lemurprints",
	"lemur.ecs.soton.ac.uk" => "lemurprints",
	"localhost" => "lemurprints"
);





1;
