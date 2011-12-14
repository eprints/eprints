package MediaWiki::API;

use warnings;
use strict;

# our required modules

use LWP::UserAgent;
use URI::Escape;
use Encode;
use JSON;
use Carp;

# just for debugging the module
# use Data::Dumper;
# use Devel::Peek;

use constant {
  ERR_NO_ERROR => 0,
  ERR_CONFIG   => 1,
  ERR_HTTP     => 2,
  ERR_API      => 3,
  ERR_LOGIN    => 4,
  ERR_EDIT     => 5,
  ERR_PARAMS   => 6,
  ERR_UPLOAD   => 7,
  ERR_DOWNLOAD => 8,

  DEF_RETRIES => 0,
  DEF_RETRY_DELAY => 0,

  DEF_MAX_LAG => undef,
  DEF_MAX_LAG_RETRIES => 4,
  DEF_MAX_LAG_DELAY => 5,

  USE_HTTP_GET => 0
};

=head1 NAME

MediaWiki::API - Provides a Perl interface to the MediaWiki API (http://www.mediawiki.org/wiki/API)

=head1 VERSION

Version 0.37

=cut

our $VERSION  = "0.37";

=head1 SYNOPSIS

This module provides an interface between Perl and the MediaWiki API (http://www.mediawiki.org/wiki/API) allowing creation of scripts to automate editing and extraction of data from MediaWiki driven sites like Wikipedia.

  use MediaWiki::API;

  my $mw = MediaWiki::API->new();
  $mw->{config}->{api_url} = 'http://en.wikipedia.org/w/api.php';

  # log in to the wiki
  $mw->login( { lgname => 'username', lgpassword => 'password' } )
    || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

  # get a list of articles in category
  my $articles = $mw->list ( {
    action => 'query',
    list => 'categorymembers',
    cmtitle => 'Category:Perl',
    cmlimit => 'max' } )
    || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

  # and print the article titles
  foreach (@{$articles}) {
      print "$_->{title}\n";
  }

  # get user info
  my $userinfo = $mw->api( {
    action => 'query',
    meta => 'userinfo',
    uiprop => 'blockinfo|hasmsg|groups|rights|options|editcount|ratelimits' } );

    ...

=head1 FUNCTIONS

=head2 MediaWiki::API->new( $config_hashref )

Returns a MediaWiki API object. You can pass a config as a hashref when calling new, or set the configuration later. When creating a new object, defaults for max lag and retries are set.

  my $mw = MediaWiki::API->new( { api_url => 'http://en.wikipedia.org/w/api.php' }  );

Configuration options are

=over

=item * api_url = 'Path to mediawiki api.php';

=item * files_url = 'Base url for files'; (needed if the api returns a relative URL for images like /images/a/picture.jpg)

=item * upload_url = 'http://en.wikipedia.org/wiki/Special:Upload'; (path to the upload special page which is required if you want to upload images)

=item * on_error = Function reference to call if an error occurs in the module.

=item * use_http_get = Boolean 0 or 1 (defaults to 0). If set to 1, the perl module will use http GET method for accessing the api. By default it uses the POST method. Note that the module will still use POST for the api calls that require POST no matter what the value of this configuration option. Currently the following actions will work with GET: query, logout, purge, paraminfo.

=item * retries = Integer value; The number of retries to send an API request if an http error or JSON decoding error occurs. Defaults to 0 (try only once - don't retry). If max_retries is set to 4, and the wiki is down, the error won't be reported until after the 5th connection attempt. 

=item * retry_delay = Integer value in seconds; The amount of time to wait before retrying a request if an HTTP error or JSON decoding error occurs.

=item * max_lag = Integer value in seconds; Wikipedia runs on a database cluster and as such high edit rates cause the slave servers to lag. If this config option is set then if the lag is more then the value of max_lag, the api will wait before retrying the request. 5 is a recommended value. More information about this subject can be found at http://www.mediawiki.org/wiki/Manual:Maxlag_parameter. note the config option includes an underscore so match the naming scheme of the other configuration options. 

=item * max_lag_delay = Integer value in seconds; This configuration option specified the delay to wait before retrying a request when the server has reported a lag more than the value of max_lag. This defaults to 5 if using the max_lag configuration option.

=item * max_lag_retries = Integer value; The number of retries to send an API request if the server has reported a lag more than the value of max_lag. If the maximum retries is reached, an error is returned. Setting this to a negative value like -1 will mean the request is resent until the servers max_lag is below the threshold or another error occurs. Defaults to 4.

=item * no_proxy = Boolean; Set to 1 to Disable use of any proxy set in the environment. Note by default if you have proxy environment variables set, then the module will attempt to use them. This feature was added at version 0.29. Versions below this ignore any proxy settings, but you can set this yourself by doing MediaWiki::API->{ua}->env_proxy() after creating a new instance of the API class. More information about env_proxy can be found at http://search.cpan.org/~gaas/libwww-perl-5.834/lib/LWP/UserAgent.pm#Proxy_attributes

=back

An example for the on_error configuration could be something like:

  $mw->{config}->{on_error} = \&on_error;

  sub on_error {
    print "Error code: " . $mw->{error}->{code} . "\n";
    print $mw->{error}->{stacktrace}."\n";
    die;
  }

Errors are stored in $mw->{error}->{code} with more information in $mw->{error}->{details}. $mw->{error}->{stacktrace} includes
the details and a stacktrace to locate where any problems originated from (in some code which uses this module for example).

The error codes are as follows

=over

=item * ERR_NO_ERROR = 0 (No error)

=item * ERR_CONFIG   = 1 (An error with the configuration)

=item * ERR_HTTP     = 2 (An http related connection error)

=item * ERR_API      = 3 (An error returned by the MediaWiki API)

=item * ERR_LOGIN    = 4 (An error logging in to the MediaWiki)

=item * ERR_EDIT     = 5 (An error with an editing function)

=item * ERR_PARAMS   = 6 (An error with parameters passed to a helper function)

=item * ERR_UPLOAD   = 7 (An error with the file upload facility)

=item * ERR_DOWNLOAD = 8 (An error with downloading a file)

=back

Other useful parameters and objects in the MediaWiki::API object are

=over

=item * MediaWiki::API->{ua} = The LWP::UserAgent object. You could modify this to get or modify the cookies (MediaWiki::API->{ua}->cookie_jar) or to change the UserAgent string sent by this perl module (MediaWiki::API->{ua}->agent)

=item * MediaWiki::API->{response} = the last response object returned by the LWP::UserAgent after an API request.

=back

=cut

sub new {

  my ($class, $config) = @_;
  
  # if no config passed make a new hash reference and get the default configuration parameters
  $config = {} if ! defined $config;
  my $defconfig = _get_config_defaults();

  $config = {%$defconfig, %$config};

  my $self = { config => $config  };

  my $ua = LWP::UserAgent->new();
  $ua->cookie_jar({});
  $ua->agent(__PACKAGE__ . "/$VERSION");
  $ua->default_header("Accept-Encoding" => "gzip, deflate");
  $ua->env_proxy() unless ($config->{no_proxy});

  $self->{ua} = $ua;

  my $json = JSON->new->utf8(1);
  $self->{json} = $json;

  # initialise error code values
  $self->{error}->{code} = 0;
  $self->{error}->{details} = '';
  $self->{error}->{stacktrace} = '';

  bless ($self, $class);
  return $self;
}

# returns a hashref with configuration defaults
sub _get_config_defaults {
  my %config;

  $config{retries} = DEF_RETRIES;
  $config{retry_delay} = DEF_RETRY_DELAY;

  $config{max_lag} = DEF_MAX_LAG;
  $config{max_lag_retries} = DEF_MAX_LAG_RETRIES;
  $config{max_lag_delay} = DEF_MAX_LAG_DELAY;
  
  $config{use_http_get} = USE_HTTP_GET;

  return \%config;
}

=head2 MediaWiki::API->login( $query_hashref )

Logs in to a MediaWiki. Parameters are those used by the MediaWiki API (http://www.mediawiki.org/wiki/API:Login). Returns a hashref with some login details, or undef on login failure. If Mediawiki sends requests a LoginToken the login is attempted again, but with the token sent from the initial login. Errors are stored in MediaWiki::API->{error}->{code} and MediaWiki::API->{error}->{details}.

  my $mw = MediaWiki::API->new( { api_url => 'http://en.wikipedia.org/w/api.php' }  );

  #log in to the wiki
  $mw->login( {lgname => 'username', lgpassword => 'password' } )
    || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

=cut

sub login {
  my ($self, $query) = @_;
  $query->{action} = 'login';
  # attempt to login, and return undef if there was an api failure
  return undef unless ( my $ref = $self->api( $query ) );

  # reassign hash reference to the login section
  my $login = $ref->{login};

  # Do login token checking
  if ( $login->{result} eq 'NeedToken' ) {
    my $token = $login->{token};
    $query->{lgtoken} = $token;
    # Re-submit previous request with token
    return undef unless ( $ref = $self->api( $query ) );
    $login = $ref->{login};
  }

  # return error if the login was not successful
  return $self->_error( ERR_LOGIN, 'Login Failure - ' . $login->{result} )
    unless ( $login->{result} eq 'Success' );
    
  # everything was ok so return the reference
  return $login;
}

=head2 MediaWiki::API->api( $query_hashref, $options_hashref )

Call the MediaWiki API interface. Parameters are passed as a hashref which are described on the MediaWiki API page (http://www.mediawiki.org/wiki/API). returns a hashref with the results of the call or undef on failure with the error code and details stored in MediaWiki::API->{error}->{code} and MediaWiki::API->{error}->{details}. MediaWiki::API uses the LWP::UserAgent module to send the http requests to the MediaWiki API. After any API call, the response object returned by LWP::UserAgent is available in $mw->{response}. This function will NOT modify the input query_hashref in any way.

  binmode STDOUT, ':utf8';

  # get the name of the site
  if ( my $ref = $mw->api( { action => 'query', meta => 'siteinfo' } ) ) {
    print $ref->{query}->{general}->{sitename};
  }

  # list of titles for "Albert Einstein" in different languages.
  my $titles = $mw->api( {
    action => 'query',
    titles => 'Albert Einstein',
    prop => 'langlinks',
    lllimit => 'max' } )
    || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

  my ($pageid,$langlinks) = each ( %{ $titles->{query}->{pages} } );

  foreach ( @{ $langlinks->{langlinks} } ) {
    print "$_->{'*'}\n";
  }

MediaWiki's API uses UTF-8 and any 8 bit character string parameters are encoded automatically by the API call. If your parameters are already in UTF-8 this will be detected and the encoding will be skipped. If your parameters for some reason contain UTF-8 data but no UTF-8 flag is set (i.e. you did not use the "use utf8;" pragma) you should prevent re-encoding by passing an option skip_encoding => 1 in the $options_hash. For example:

 my $mw = MediaWiki::API->new();
 $mw->{config}->{api_url} = 'http://fr.wiktionary.org/w/api.php';

 my $query = {action => 'query',
   list => 'categorymembers',
   cmlimit => 'max'};

 $query->{cmtitle} ="Cat\x{e9}gorie:moyen_fran\x{e7}ais"; # latin1 string
 $mw->list ( $query ); # ok 

 $query->{cmtitle} = "Cat". pack("U", 0xe9)."gorie:moyen_fran".pack("U",0xe7)."ais"; # unicode string
 $mw->list ( $query ); # ok

 $query->{cmtitle} ="Cat\x{c3}\x{a9}gorie:moyen_fran\x{c3}\x{a7}ais";  # unicode data without utf-8 flag
 # $mw->list ( $query ); # NOT OK
 $mw->list ( $query, {skip_encoding => 1} ); # ok

If you are calling an API function which requires a file upload, e.g. import or upload, specify the file to upload as an arrayref containing the local filename. The API may return a warning, for example to say the file is a duplicate. To ignore warnings and force an upload, use ignorewarnings => 1. All the parameters as with everything else can be found on the MediaWiki API page.

 $mw->api( {
   action => 'import',
   xml => ['wiki_dump.xml']
  } );

 $mw->api( {
   action => 'upload',
   filename => 'test.png',
   comment => 'a test image',
   file => ['test.png'],
  } );

You can also give the data to be uploaded directly, should you want to read the data in yourself. In this case, supply an arrayref with three parameters, starting with an "undef", followed by the filename, and then a Content => $data pair containing the data.

 $mw->api( {
   action => 'import',
   xml => [ undef, 'wiki_dump.xml', Content => $data ]
  } );

 $mw->api( {
   action => 'upload',
   filename => 'test.png',
   comment => 'a test image',
   file => [ undef, 'test.png', Content => $data ],
  } );

=cut

sub api {
  my ($self, $query, $options) = @_;

  return $self->_error(ERR_CONFIG,"You need to give the URL to the mediawiki API php.")
    unless $self->{config}->{api_url};

  my $get_actions = {
    'query' => 1,
    'logout' => 1,
    'purge' => 1,
    'paraminfo' => 1
  };

  my $retries = $self->{config}->{retries};
  my $maxlagretries = $self->{config}->{max_lag_retries};

  $self->_encode_hashref_utf8($query, $options->{skip_encoding});
  $query->{maxlag} = $self->{config}->{max_lag} if defined $self->{config}->{max_lag}; 
  $query->{format}='json';

  # if the config is set to use GET we need to contruct a querystring. some actions are "POST" only -
  # edit, move, action = rollback, action = undelete, action = 
  my $querystring = '';
  if ( $self->{config}->{use_http_get} && defined $get_actions->{$query->{action}} ){
    $querystring = _make_querystring( $query );
  }

  my $ref;
  while (1) {

    # connection retry loop.
    foreach my $try (0 .. $retries) {

      # if we are already retrying, then wait the specified delay
      if ( $try > 0 ) {
        sleep $self->{config}->{retry_delay};
      }

      my $response;
      my %headers;
      # if we are using the get method ($querystring is set above)
      if ( $querystring ) {
        $response = $self->{ua}->get( $self->{config}->{api_url} . $querystring, %headers );
      } else {
        $headers{'content-type'} = 'form-data' if $query->{action} eq 'upload' || $query->{action} eq 'import';
        $response = $self->{ua}->post( $self->{config}->{api_url}, $query, %headers );
      }
      $self->{response} = $response;
      
      # if the request was successful then check the returned content and decode.
      if ( $response->is_success ) {
        
        my $decontent = $response->decoded_content( charset => 'none' );

        if ( ! defined $decontent ) {
          return $self->_error(ERR_HTTP,"Unable to decode content returned by $self->{config}->{api_url} - Unknown content encoding?")
            if ( $try == $retries );
          next;
        }
        
        if ( length $decontent == 0 ) {
          return $self->_error(ERR_HTTP,"$self->{config}->{api_url} returned a zero length string")
            if ( $try == $retries );
          next;
        }

        # decode the json trapping any errors
        eval {
          $ref = $self->{json}->decode($decontent);
        };

        if ( $@) {
          # an error occurred, so we check if we need to retry and continue
          my $error = $@;
          return $self->_error(ERR_HTTP,"Failed to decode JSON returned by $self->{config}->{api_url}\nDecoding Error:\n$error\nReturned Data:\n$decontent")
            if ( $try == $retries );
          next;
        } else {
          # no error so we want out of the retry loop
          last;
        }

      # if the request was not successful then we retry or return a failure if the maximum retries
      # have been reached, otherwise we try again
      } else {
        return $self->_error(ERR_HTTP, $response->status_line . " : error occurred when accessing $self->{config}->{api_url} after " . ($try+1) . " attempt(s)")
          if ( $try == $retries );
        next;
      }       
      
    }

    return $self->_error(ERR_API,"API has returned an empty array reference. Please check your parameters") if ( ref($ref) eq 'ARRAY' && scalar @{$ref} == 0);

    # check lag and wait
    if (ref($ref) eq 'HASH' && exists $ref->{error} && $ref->{error}->{code} eq 'maxlag' ) {
      $ref->{'error'}->{'info'} =~ /: (\d+) seconds lagged/;
      my $lag = $1;
      if ($maxlagretries == 0) {
        return $self->_error(ERR_API,"Server has reported lag above the configure max_lag value of " . $self->{config}->{max_lag} . " value after " .($maxlagretries+1)." attempt(s). Last reported lag was - ". $ref->{'error'}->{'info'})
      } else {
        sleep $self->{config}->{max_lag_delay};
        $maxlagretries-- if $maxlagretries > 0;
        # redo the request
        next;
      }

    }

    # if we got this far, then we have a hashref from the api and we want out of the while loop
    last;

  }

  return $self->_error(ERR_API,$ref->{error}->{code} . ": " . $ref->{error}->{info} ) if ( ref($ref) eq 'HASH' && exists $ref->{error} );

  return $ref;
}

=head2 MediaWiki::API->logout()

Log the current user out and clear associated cookies and edit tokens.

=cut

sub logout {
  my ($self) = @_;
  # clear login cookies
  $self->{ua}->{cookie_jar} = undef;
  # clear cached tokens
  $self->{config}->{tokens} = undef;
}

=head2 MediaWiki::API->edit( $query_hashref, $options_hashref )

A helper function for doing edits using the MediaWiki API. Parameters are passed as a hashref which are described on the MediaWiki API editing page (http://www.mediawiki.org/wiki/API:Changing_wiki_content). Note that you need $wgEnableWriteAPI = true in your LocalSettings.php to use these features. This function will modify the input hashref.

Currently

=over

=item * Create/Edit pages (Mediawiki >= 1.13 )

=item * Move pages (Mediawiki >= 1.12 )

=item * Rollback (Mediawiki >= 1.12 )

=item * Delete pages (Mediawiki >= 1.12 )

=item * Upload images (Mediawiki >= 1.16 )

=item * Import pages (Mediawiki >= 1.15 )

=item * (Un)protect pages (Mediawiki >= 1.12 )

=item * (Un)block users (Mediawiki >= 1.12 )

=back

are supported via this call. Use this call to edit pages without having to worry about getting an edit token from the API first. The function will cache edit tokens to speed up future edits (Except for rollback edits, which are not cachable).

Returns a hashref with the results of the call or undef on failure with the error code and details stored in MediaWiki::API->{error}->{code} and MediaWiki::API->{error}->{details}.

The options hashref currently has one optional parameter (skip_encoding => 1). This is described above in the MediaWiki::API->api call documentation.

Here are some example snippets of code. The first example is for adding some text to an existing page (if the page doesn't exist nothing will happen). Note that the timestamp for the revision we are changing is saved. This allows us to avoid edit conflicts. The value is passed back to the edit function, and if someone had edited the page in the meantime, an error will be returned.

  my $pagename = "Wikipedia:Sandbox";
  my $ref = $mw->get_page( { title => $pagename } );
  unless ( $ref->{missing} ) {
    my $timestamp = $ref->{timestamp};
    $mw->edit( {
      action => 'edit',
      title => $pagename,
      basetimestamp => $timestamp, # to avoid edit conflicts
      text => $ref->{'*'} . "\nAdditional text" } )
      || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};
  }

The following code deletes a page with the name "DeleteMe". You can specify a reason for the deletion, otherwise
a generated reason will be used.

  # delete a page
  $mw->edit( {
    action => 'delete', title => 'DeleteMe', reason => 'no longer needed' } ) 
    || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

This code moves a page from MoveMe to MoveMe2.

  # move a page
  $mw->edit( {
    action => 'move', from => 'MoveMe', to => 'MoveMe2' } )
    || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

The following scrippet rolls back one or more edits from user MrVandal. If the user is not the last editor of the page, an error will be returned. If no user is passed, the edits for whoever last changed the page will be rolled back.

  $mw->edit( {
    action => 'rollback', title => 'Sandbox', user => 'MrVandal' } )
    || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

=cut

sub edit {
  my ($self, $query, $options) = @_;

  # gets and sets a token for the specific action (different tokens for different edit actions such as rollback/delete etc).
  return undef unless ( $self->_get_set_tokens( $query ) );

  # do the edit
  return undef unless ( my $ref = $self->api( $query, $options ) );

  return $ref;
}


=head2 MediaWiki::API->get_page( $params_hashref )

A helper function for getting the most recent page contents (and other metadata) for a page. It calls the lower level api function with a revisions query to get the most recent revision.

  # get some page contents
  my $page = $mw->get_page( { title => 'Main Page' } );
  # print page contents
  print $page->{'*'};

Returns a hashref with the following keys or undef on an error. If the page is missing then the returned hashref will contain only ns, title and a key called "missing".

=over

=item * '*' - contents of page

=item * 'pageid' - page id of page

=item * 'revid' - revision id of page

=item * 'timestamp' - timestamp of revision

=item * 'user' - user who made revision

=item * 'title' - the title of the page

=item * 'ns' - the namespace the page is in

=item * 'size' - size of page in bytes

=back

Full information about these can be read on (http://www.mediawiki.org/wiki/API:Query_-_Properties#revisions_.2F_rv)

=cut

sub get_page {
  my ($self, $params) = @_;
  return undef unless ( my $ref = $self->api( { action => 'query', prop => 'revisions', titles => $params->{title}, rvprop => 'ids|flags|timestamp|user|comment|size|content' } ) );
  # get the page id and the page hashref with title and revisions
  my ($pageid, $pageref) = each %{ $ref->{query}->{pages} };
  # get the first revision
  my $rev = @{ $pageref->{revisions } }[0];
  # delete the revision from the hashref
  delete($pageref->{revisions});
  # if the page is missing then return the pageref
  return $pageref if ( defined $pageref->{missing} );
  # combine the pageid, the latest revision and the page title into one hash
  return { 'pageid'=>$pageid, %{ $rev }, %{ $pageref } };
}

=head2 MediaWiki::API->list( $query_hashref, $options_hashref )

A helper function for getting lists using the MediaWiki API. Parameters are passed as a hashref which are described on the MediaWiki API editing page (http://www.mediawiki.org/wiki/API:Query_-_Lists). This function modifies the input query_hashref.

This function will return a reference to an array of hashes or undef on failure. It handles getting lists of data from the MediaWiki api, continuing the request with another connection if needed. The options_hashref currently has three parameters:

=over

=item * max => value

=item * hook => \&function_hook

=item * skip_encoding => 1

=back

The value of max specifies the maximum "queries" which will be used to pull data out. For example the default limit per query is 10 items, but this can be raised to 500 for normal users and higher for sysops and bots. If the limit is raised to 500 and max was set to 2, a maximum of 1000 results would be returned.

If you wish to process large lists, for example the articles in a large category, you can pass a hook function, which will be passed a reference to an array of results for each query connection.

The skip_encoding parameter works as described above in the MediaWiki::API->api call documentation.

  binmode STDOUT, ':utf8';

  # process the first 400 articles in the main namespace in the category "Surnames".
  # get 100 at a time, with a max of 4 and pass each 100 to our hook.
  $mw->list ( { action => 'query',
                list => 'categorymembers',
                cmtitle => 'Category:Surnames',
                cmnamespace => 0,
                cmlimit=>'100' },
              { max => 4, hook => \&print_articles } )
  || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

  # print the name of each article
  sub print_articles {
    my ($ref) = @_;
    foreach (@$ref) {
      print "$_->{title}\n";
    }
  }

=cut

sub list {
  my ($self, $query, $options) = @_;
  my ($ref, @results);
  my ($cont_key, $cont_value, $array_key);

  my $list = $query->{list};

  $options->{max} = 0 if ( !defined $options->{max} );

  my $continue = 0;
  my $count = 0;
  do {
    return undef unless ( $ref = $self->api( $query, $options ) );

    # return (empty) arrayref if there are no results
    return \@results unless ( $ref->{query}->{$list} );

    # check if there are more results to be had
    if ( exists( $ref->{'query-continue'} ) ) {
      # get query-continue hashref and extract key and value (key will be used as from parameter to continue where we left off)
      ($cont_key, $cont_value) = each( %{ $ref->{'query-continue'}->{$list} } );
      $query->{$cont_key} = $cont_value;
      $continue = 1;
    } else {
      $continue = 0;
    }

    if ( defined $options->{hook} ) {
      $options->{hook}( $ref->{query}->{$list} );
    } else {
      push @results, @{ $ref->{query}->{$list} };
    }

    $count += 1;

  } until ( ! $continue || $count >= $options->{max} && $options->{max} != 0 );

  return 1 if ( defined $options->{hook} ); 
  return \@results;

}

=head2 MediaWiki::API->upload( $params_hashref )

This function is deprecated. For uploading on mediawiki versions 1.16 or later, you are recommended to use MediaWiki::API->edit or MediaWiki::API->api directly, which has much better
error handling, and supports uploading files by just passing a filename.

A function to upload files to a MediaWiki. This function does not use the MediaWiki API currently as support for file uploading is not yet implemented. Instead it uploads using the Special:Upload page, and as such an additional configuration value is needed.

  my $mw = MediaWiki::API->new( {
   api_url => 'http://en.wikipedia.org/w/api.php' }  );
  # configure the special upload location.
  $mw->{config}->{upload_url} = 'http://en.wikipedia.org/wiki/Special:Upload';

The upload function is then called as follows

  # upload a file to MediaWiki
  open FILE, "myfile.jpg" or die $!;
  binmode FILE;
  my ($buffer, $data);
  while ( read(FILE, $buffer, 65536) )  {
    $data .= $buffer;
  }
  close(FILE);

  $mw->upload( { title => 'file.jpg',
                 summary => 'This is the summary to go on the Image:file.jpg page',
                 data => $data } ) || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

Error checking is limited. Also note that the module will force a file upload, ignoring any warning for file size or overwriting an old file.

=cut

sub upload {
  my ($self, $params) = @_;

  # get the version of mediawiki running, and if less than 1.16 use the old upload mechanism
  my $mwver = $self->_get_version;
  $mwver =~ /(\d+)\.(\d+)/;
  if ( $1 == 1 && $2 < 16 ) {
    return $self->_upload_old($params);
  }

  my $query;
  $query->{action} = 'upload';
  $query->{filename} = $params->{title};
  $query->{comment} = $params->{summary};
  $query->{file} = [ undef, $params->{title}, Content => $params->{data} ];
  $query->{ignorewarnings} = 1;
  return $self->edit($query);
}

sub _upload_old {
  my ($self, $params) = @_;

  return $self->_error(ERR_CONFIG,"You need to give the URL to the mediawiki Special:Upload page.") unless $self->{config}->{upload_url};

  my $response = $self->{ua}->post(
    $self->{config}->{upload_url},
    Content_Type => 'multipart/form-data',
    Content => [
      wpUploadFile => [ undef, $params->{title}, Content => $params->{data} ],
      wpSourceType => 'file',
      wpDestFile => $params->{title},
      wpUploadDescription => $params->{summary},
      wpUpload => 'Upload file',
      wpIgnoreWarning => 'true', ]
  );

  return $self->_error(ERR_UPLOAD,"There was a problem uploading the file - $params->{title}") unless ( $response->code == 302 );
  return 1;
}

=head2 MediaWiki::API->download( $params_hashref )

A function to download images/files from a MediaWiki. A file url may need to be configured if the api returns a relative URL.

  my $mw = MediaWiki::API->new( {
    api_url => 'http://www.exotica.org.uk/mediawiki/api.php' }  );
  # configure the file url. Wikipedia doesn't need this but the ExoticA wiki does.
  $mw->{config}->{files_url} = 'http://www.exotica.org.uk';

The download function is then called as follows

  my $file = $mw->download( { title => 'Image:Mythic-Beasts_Logo.png'} )
    || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

If the file does not exist (on the wiki) an empty string is returned. If the file is unable to be downloaded undef is returned.

=cut

sub download {
  my ($self, $params) = @_;

  return $self->_error(ERR_PARAMS,"You need to give a name for the Image page") unless
    ( defined $params->{title} );

  return undef unless my $ref = $self->api(
    { action => 'query',
      titles => $params->{title},
      prop   => 'imageinfo',
      iiprop => 'url' } );

  # get the page id and the page hashref with title and revisions
  my ( $pageid, $pageref ) = each %{ $ref->{query}->{pages} };

  # if the image is missing then return an empty string
  return '' unless ( defined $pageref->{imageinfo} );

  my $url = @{ $pageref->{imageinfo} }[0]->{url};

  unless ( $url =~ /^http\:\/\// ) {
    return $self->_error(ERR_PARAMS,'The API returned a relative path. You need to configure the url where files are stored in {config}->{files_url}')
      unless ( defined $self->{config}->{files_url} );
    $url = $self->{config}->{files_url} . $url;
  }

  my $response = $self->{ua}->get($url);
  return $self->_error(ERR_DOWNLOAD,"The file '$url' was not found")
    unless ( $response->code == 200 );

  return $response->decoded_content;
}

# returns the version of mediawiki being run 
sub _get_version {
  my ($self) = @_;
  return $self->{config}->{mw_ver} if exists( $self->{config}->{mw_ver} );
  return undef unless my $ref = $self->api(
    {
      action => 'query',
      meta   => 'siteinfo'
    } );
  my $mwver = $ref->{query}->{general}->{generator};
  $mwver =~ s/.+?(\d+\.\d+).*/$1/;
  $self->{config}->{mw_ver} = $mwver;
  return $mwver;
}

# returns a copy of a hash (passed by reference) encoded to utf-8
# used to encode parameters before being passed to the api
sub _encode_hashref_utf8 {
  my $uriver = $URI::VERSION;
  my ($self, $ref, $skipenc) = @_;
  for my $key ( keys %{$ref} ) {
    # skip to next item if no value defined or the item is a ref (i.e. a file upload)
    next if ! defined $ref->{$key} || ref($ref->{$key});
    # if we don't want to skip encoding and the item doesn't already have the utf8 flag set or we are using
    # an older version of URI.pm that doesn't handle the encoding correctly then we need to encode to utf8
    if ( ! $skipenc && ( ! utf8::is_utf8($ref->{$key}) || $URI::VERSION < 1.36) ) {
      $ref->{$key} = Encode::encode_utf8($ref->{$key});
    }
    # turn on the utf8 flag so the URI module knows what to do with it (and so we don't re-encode when we don't need to)
    # if we are using a new enough version of URI that will handle the encoding correctly.
    # so what you get is :
    # URI <  1.36 - utf8 encoded string without utf8 flag (works)
    # URI >= 1.36 - utf8 encoded string with utf8 flag (works)
    Encode::_utf8_on($ref->{$key}) if $URI::VERSION >= 1.36;
  }

  return $ref;
}

# creates a querystring from a utf-8 hashref
sub _make_querystring {
  my ($ref) = @_;
  my @qs = ();
  my $keyval;
  for my $key ( keys %{$ref} ) {
    $keyval = uri_escape_utf8($key) . '=' . uri_escape_utf8($ref->{$key});
    push(@qs, $keyval);
  }
  return '?' . join('&',@qs);
}

# gets a token for a specified parameter and sets it in the query for the call
sub _get_set_tokens {
  my ($self, $query) = @_;
  my ($prop, $title, $token);
  
  my $action = $query->{action};

  if ( $action eq 'move' ) {
    $title = $query->{from};
  } else {
    $title = $query->{title};
  }

  if ( $action eq 'upload' ) {
    $action = 'edit';
    $title = $query->{filename};
  }

  # check if we have a cached token.
  if ( exists( $self->{config}->{tokens}->{$action} ) ) {
    $query->{token} = $self->{config}->{tokens}->{$action};
    return 1;
  }

  # if we are doing an import, get the edit token using Main_Page as API docs suggest.
  if ( $action eq 'import' ) {
    # if a title is supplied use that page to get the edit token instead of Main_Page
    if ( defined $query->{title} ) {
      $title = $query->{title};
    } else {
      $title = "Main_Page";
    }
  }

  # set the properties we want to extract based on the action
  if ( $action eq 'rollback' ) {
    $prop = 'revisions'; 
  } else {
    $prop = 'info';
  }

  $token = 'intoken';
  $token = 'rvtoken' if ( $action eq 'rollback' );

  return undef unless ( my $ref = $self->api( { action => 'query', prop => $prop, $token => $action, titles => $title } ) );

  my ($pageid, $pageref) = each %{ $ref->{query}->{pages} };

  # if the page doesn't exist and we aren't editing/creating a new page then return an error
  if ( defined $pageref->{missing} && $action ne 'edit' && $action ne 'import' ) {
    return $self->_error( ERR_EDIT, "Unable to $action page '$title'. Page does not exist.") 
  }

  if ( $action eq 'rollback' ) {
    $query->{token} = @{ $pageref->{revisions} }[0]->{$action.'token'};
    my $lastuser = @{ $pageref->{revisions} }[0]->{user};
    $query->{user} = @{ $pageref->{revisions} }[0]->{user} unless defined $query->{user};
    return $self->_error( ERR_EDIT, "Unable to rollback edits from user '$query->{user}' for page '$title'. Last edit was made by user $lastuser" ) if ( $query->{user} ne $lastuser );
  } else {
    $query->{token} = $pageref->{$action.'token'};
  }

  return $self->_error( ERR_EDIT, "Unable to get an edit token for action '$action'." ) unless ( defined $query->{token} );

  # cache the token. rollback tokens are specific for the page name and last edited user so can not be cached. Note that although currently many of the tokens
  # are equivalent, we cache them separately in case this was to change.
  if ( $action ne 'rollback' ) {
    $self->{config}->{tokens}->{$action} = $query->{token};
  }

  return 1;
}

sub _error {
  my ($self, $code, $desc) = @_;
  $self->{error}->{code} = $code;
  $self->{error}->{details} = $desc;
  $self->{error}->{stacktrace} = Carp::longmess($desc);

  $self->{config}->{on_error}->() if (defined $self->{config}->{on_error});

  return undef;
}

__END__

=head1 AUTHOR

Jools 'BuZz' Wills, C<< <buzz [at] exotica.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-mediawiki-api at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=MediaWiki-API>.  I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc MediaWiki::API


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=MediaWiki-API>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/MediaWiki-API>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/MediaWiki-API>

=item * Search CPAN

L<http://search.cpan.org/dist/MediaWiki-API>

=back


=head1 ACKNOWLEDGEMENTS

=over

=item * Carl Beckhorn (cbeckhorn [at] fastmail.fm) for ideas and support

=item * Stuart 'Kyzer' Caie (kyzer [at] 4u.net) for UnExoticA perl code and support

=item * Edward Chernenko (edwardspec [at] gmail.com) for his earlier MediaWiki module

=item * Dan Collins (EN.WP.ST47 [at] gmail.com) for bug reports and patches

=item * Jonas 'Spectral' Nyren (spectral [at] ludd.luth.se) for hints and tips!

=item * Jason 'XtC' Skelly (xtc [at] amigaguide.org) for moral support

=item * Nikolay Shaplov (n [at] shaplov.ru) for utf-8 patches and testing

=item * Jeremy Muhlich (jmuhlich [at] bitflood.org) for utf-8 patches and testing for api upload support patch

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008 - 2011 Jools Wills, all rights reserved.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut

1; # End of MediaWiki::API
