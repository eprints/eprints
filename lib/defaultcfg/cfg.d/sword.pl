#####################################################################################
# 
# SWORD Configuration File
#
#####################################################################################

use strict;

my $sword = {};
$c->{sword} = $sword;

# Defines the allowed mediation. By default no mediations are allowed.
$sword->{allowed_mediations} = 
{
#	"*" => ["*"],		# ALLOW ANY MEDIATIONS
#	"seba" => ["admin"],	# ALLOW 'seba' TO DEPOSIT FOR 'admin'
#	"seba" => ["*"],	# ALLOW 'seba' TO DEPOSIT FOR EVERYONE

};

# Override the default settings for the service (only title and generator).
$sword->{service_conf} = {
#	title => "EPrints Repository",
#	generator => "EPrints Repositor",
};

# All collections inherit this: (in other words all collections accept the same MIME types)
$sword->{accept_mime_types} = 
[
	"*/*",
];

# Defines the available collections on this repository.
$sword->{collections} = 
{
	"inbox" => 
	{
			title => "User Area",
			sword_policy => "This collection accepts packages from any registered users on this repository.",
			dcterms_abstract => "This is your user area.",
			mediation => "true",	#false to turn off mediation for that collection
			treatment => "Deposited items will remain in your user inbox until you manually send them for reviewing.",
			#accept_mime_types => [ "image/jpeg", "application/pdf" ],
	},

       "buffer" => 
	{
                        title => "Repository Review",   # title of this collection
                        sword_policy => "",
                        dcterms_abstract => "This is the repository review.",
                        mediation => "true",    #false to turn off mediation for that collection
                        treatment => "Deposited items will undergo the review process. Upon approval, items will appear in the live repository.",
        },

# By default, the live archive is disabled. Comment out to re-enable it.
#	"archive" => {
#			title => "Live Repository",
#			sword_policy => "Live archive policy",
#			dcterms_abstract => "This is the live repository",
#			mediation => "true",
#			treatment => "Deposited items will appear publicly.",
#	},

};

$sword->{enable_generic_importer} = 1;

$sword->{supported_packages} =
{
	"http://eprints.org/ep2/data/2.0" => 
		{
			name => "EPrints XML",
			plugin => "Sword::Import::EPrintsXML",
			qvalue => "1.0"
		},
	"http://www.loc.gov/METS/" => 
		{
			name => "METS",
			plugin => "Sword::Import::METS",
			qvalue => "0.2"
		},
	
	"http://www.imsglobal.org/xsd/imscp_v1p1" =>
		{
			name => "IMS Content Packaging 1.1.x",
			plugin => "Sword::Import::IMS",
			qvalue => "0.2"			
		},
    "http://purl.org/net/sword-types/METSDSpaceSIP" =>
        {
            name => "METS DSpace SIP",
            plugin => "Sword::Import::METS",
            qvalue => "0.2"
        },
};










