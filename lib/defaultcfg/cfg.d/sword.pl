#####################################################################################
# 
# SWORD Configuration File
#
# Refer to the documentation for more details.
#
# (SWORD is a protocol to add things to the repository)
#
#####################################################################################

use strict;

my $sword = {};
$c->{sword} = $sword;

# To disable authentication:
#$sword->{disable_authentication} = 0;
#$sword->{anonymous_user} = "";


# Defines the allowed mediation. By default no mediations are allowed.
$sword->{allowed_mediation} = {

#	"*" => ["*"],		# ALLOW ANY MEDIATIONS
#	"seba" => ["admin"],	# ALLOW 'seba' TO DEPOSIT FOR 'admin'
#	"seba" => ["*"],	# ALLOW 'seba' TO DEPOSIT FOR EVERYONE

};

# Override the default settings for the service (only title and generator).
$sword->{service_conf} = {
#	title => "EPrints Repository",
#	generator => "EPrints Repositor",
};



# Defines the available collections on this repository.
$sword->{collections_conf} = {

	"inbox" => {
			title => "User Inbox",
			sword_policy => "This collection accepts packages from any registered users on this repository.",
			dcterms_abstract => "This is your user inbox.",
			mediation => "true",	#false to turn off mediation for that collection
			treatment => "Deposited items will remain in your user inbox until you manually send them for reviewing.",

			# the fields below will override the default settings:
			# format_ns => ["http://eprints.org/ep2/data/2.0"],
			# accept_mime => ["application/zip"],
			# href => "http://myserver.org/inbox",
	},

       "buffer" => {
                        title => "Repository Review",   # title of this collection
                        sword_policy => "",
                        dcterms_abstract => "This is the repository review. ",
                        mediation => "true",    #false to turn off mediation for that collection
                        treatment => "Deposited items will undergo the review process. Upon approval, items will appear in the live repository.",

			# the fields below will override the default settings:
			# format_ns => ["http://eprints.org/ep2/data/2.0"],
			# accept_mime => ["application/zip"],
			# href => "http://myserver.org/inbox",
        },


# By default, the live archive is disabled. Comment out to re-enable it.
#	"archive" => {
#			title => "Live Repository",
#			sword_policy => "",
#			dcterms_abstract => "",
#			mediation => "true",
#			treatment => "Deposited items will appear publicly.",
#
#			# the fields below will override the default settings:
#			# format_ns => ["http://eprints.org/ep2/data/2.0"],
#			# accept_mime => ["application/zip"],
#			# href => "http://myserver.org/inbox",
#
#	},


};




# Set this to 0 if you don't want to keep the files sent through SWORD. By default they are attached to the newly created eprints.
$sword->{keep_deposited_files} = 1;



# Maps supported MIME types to Sword::Unpack plugins
$sword->{mime_types} = {

	"application/x-zip" => { 
				plugin => "Sword::Unpack::Zip", 
				direct_import => 0  
			},

	"application/pdf" => {
				plugin => "Sword::Import::Pdf",
				direct_import => 1,
			},

	"image/jpeg" => {
				plugin => "Sword::Import::Jpeg",
				direct_import => 1
			},

	"image/png" => {
				plugin => "Sword::Import::Png",
				direct_import => 1
			},

	"image/x-png" => {
				plugin => "Sword::Import::Png",
                                direct_import => 1
                         },


	"application/zip" => {
				plugin => "Sword::Unpack::Zip",
				direct_import => 0
			},

# we can't do a direct import on XML as we need to know the namespace!!
	"application/xml" => {
				plugin => "Sword::Unpack::XML",
				direct_import => 0
			},

	"text/xml" => {
			plugin => "Sword::Unpack::XML",
			direct_import => 0
		},
};



# Maps supported (Pseudo-)Namespaces to Sword::Import plugins
$sword->{importers} = {

	"http://eprints.org/ep2/data/2.0" => "Sword::Import::EPrintsXML",

	"IMS" => "Sword::Import::IMS",
	"http://www.imsglobal.org/xsd/imscp_v1p1" => "Sword::Import::IMS",

	"METS" => "Sword::Import::METS",
	"http://www.loc.gov/METS/" => "Sword::Import::METS",

	"PDF" => "Sword::Import::Pdf",
	"JPEG" => "Sword::Import::Jpeg",
	"PNG" => "Sword::Import::Png",
};


