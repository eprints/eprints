
# path of site on server with no trailing slash
$c->{urlpath} = "";

# Server of static HTML + images, including port but without trailing
#slash
$c->{base_url} = "http://$c->{host}".($c->{port}!=80?":".$c->{port}:"").$c->{urlpath};

# Mod_perl script base URL
$c->{perl_url} = $c->{base_url}."/cgi";

# URL of secure document file hierarchy. EPrints needs to know the
# path from the baseurl as this is used by the authentication module
# to extract the document number from the url, eg.
# http://www.lemurprints.org/secure/00000120/01/index.html
#$c->{secure_urlpath} = "/secure"; 
#$c->{secure_url} = $c->{base_url}.$c->{secure_urlpath};

