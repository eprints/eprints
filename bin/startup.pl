use strict;
           
# Extend @INC if needed
use lib qw( /opt/eprints/perl_lib );
           
# Make sure we are in a sane environment.
$ENV{MOD_PERL} or die "not running under mod_perl!";
            
# For things in the "/perl" URL
use Apache::Registry;          
 
# Load Perl modules of your choice here
# This code is interpreted *once* when the server starts

use EPrints::Auth;
use EPrints::Citation;
use EPrints::Database;
use EPrints::Deletion;
use EPrints::Document;
use EPrints::EPrint;
use EPrints::HTMLRender;
use EPrints::ImportXML;
use EPrints::Language;
use EPrints::Log;
use EPrints::Mailer;
use EPrints::MetaField;
use EPrints::Name;
use EPrints::OpenArchives;
use EPrints::Site;
use EPrints::Site::General;
use EPrints::SearchExpression;
use EPrints::SearchField;
use EPrints::Session;
use EPrints::SubjectList;
use EPrints::Subject;
use EPrints::SubmissionForm;
use EPrints::Subscription;
use EPrints::UserForm;
use EPrints::User;
use EPrints::Version;


# Tell me more about warnings
use Carp ();
$SIG{__WARN__} = \&Carp::cluck;

