
######################################################################
#
# %entities = get_entities( $repository , $langid );
#
######################################################################
# $repository 
# - the repository object
# $langid 
# - the 2 digit language ID string
#
# returns %entities 
# - a HASH which maps 
#      entity name string
#   to 
#      entity value string
#
######################################################################
# get_entities is used by eprints to get the entities
# for the phrase files and config files. 
#
# When EPrints loads the repository config, it is called once for each
# supported language, although that probably only affects the repository
# name.
#
# It should not need editing, unless you want to add entities to the
# DTD file. You might want to do that to help automate a large system.
#
######################################################################

sub get_entities
{
	my( $repository, $langid ) = @_;
	my %entities = ();

	$entities{archivename} = "Fix ticket 2406!";
	$entities{adminemail} = $repository->get_conf( "adminemail" );
	$entities{base_url} = $repository->get_conf( "base_url" );
	$entities{perl_url} = $repository->get_conf( "perl_url" );
	$entities{https_base_url} = "https://" . $repository->get_conf("securehost") . $repository->get_conf("securepath");
	$entities{frontpage} = $repository->get_conf( "frontpage" );
	$entities{userhome} = $repository->get_conf( "userhome" );
	$entities{version} = EPrints::Config::get( "version" );
	$entities{ruler} = '<hr noshade="noshade" class="ep_ruler" />';
	$entities{logo} = '<img alt="Logo" src="'.$repository->get_conf("site_logo").'" />';

	return %entities;
}
