use strict;


$ENV{MOD_PERL} or EPrints::Config::abort( "not running under mod_perl!" );

print STDERR "EPRINTS: Loading Modules\n";

# Extend @INC if needed
use lib ( $ENV{EPRINTS_PATH}."/perl_lib" );

## Apache::DBI MUST come before other modules using DBI or
## you won't get constant connections and everything
## will go horribly wrong...

use Apache::DBI;

use Apache::Registry;          
 
# Load Perl modules of your choice here
# This code is interpreted *once* when the server starts

$Apache::DBI::DEBUG = 3;

use EPrints::Config;
use EPrints::Auth;
use EPrints::Database;
use EPrints::Deletion;
use EPrints::Document;
use EPrints::EPrint;
use EPrints::HTMLRender;
use EPrints::ImportXML;
use EPrints::Language;
use EPrints::Mailer;
use EPrints::MetaField;
use EPrints::Name;
use EPrints::OpenArchives;
use EPrints::Archive;
use EPrints::SearchExpression;
use EPrints::SearchField;
use EPrints::Session;
use EPrints::Subject;
use EPrints::SubmissionForm;
use EPrints::Subscription;
use EPrints::UserForm;
use EPrints::User;
use EPrints::Version;

print STDERR "EPRINTS: Modules Loaded\n";

# cjg SYSTEM CONF SHOULD SAY IF TO PRELOAD OR NOT...

my %done = ();
foreach( EPrints::Config::get_archive_ids() )
{
	next if $done{$_};
	print STDERR "Preloading: ".$_."\n";
	EPrints::Archive->new_archive_by_id( $_ );
}


# Tell me more about warnings
use Carp ();
$SIG{__WARN__} = \&Carp::cluck;

1;
