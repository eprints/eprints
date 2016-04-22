=head1 NAME

EPrints::Sword::DepositClient

=cut

package EPrints::Sword::DepositClient;

use strict;
use warnings;

use English;
use File::stat;
use LWP::UserAgent;
#use XML::XPath;

our $config = {};
our $debug = undef;

sub check_config {
	if (!defined $config->{host} || !defined $config->{username} || !defined $config->{password}) 
	{     
                return("critical_parameters");
        } 
       
       	if (!defined $config->{realm}) {
		$config->{realm} = "";
	}

        my $given_url = $config->{host};

        my $host = $config->{host};

        if ((substr $host,0,7) eq "http://") {
                $host = substr $host, 7;
        }

        if ((index $host,"/") > 0) {
                $host = substr $host,0,index($host,"/");
        }

        if (!((index $host,":") > 0)) {
                $host = $host . ":80";
        }
	
	        $config->{host} = $host;

        $config->{sword_url} = $host;
        
        if (create_container(undef,undef,1)) {
                return 1;
        }

        use File::Temp;
        my $fh = File::Temp->new();
        my $stuff = get_file_from_uri($fh,$given_url,"text/html");
        my $uri = get_sword_uri_from_html($fh);
        if (defined $uri) {
                $config->{sword_url} = $uri;
                if (create_container(undef,undef,1)) {
			if ($debug) { print "[STARTUP] Deposit Connection Established\n[STARTUP] Completed\n\n"; }
                        return 1;
                }
        }

        if ($debug) { print "[CRITICAL] Configuration Failed, no connection to the endpoint could be established, please check the Config file for errors.\n"; }

        return undef;
}

sub get_file_from_uri {

        my $file = shift;
        my $uri = shift;
        my $accept_type = shift;

        if ($debug) { print "[MESSAGE] Attempting to get $file from $uri\n"; }

        my $ua = get_user_agent(undef);

        open(FILE, ">", "$file" ) or die("can't open input file");
        binmode FILE;

        my $h;
        my $req;

        if (defined $accept_type) {
                $h = HTTP::Headers->new(Accept => $accept_type);
                $req = HTTP::Request->new( GET => $uri, $h );
        } else {
                $req = HTTP::Request->new( GET => $uri );
        }

        my $file_handle = "";

        # Et Zzzzooo!
        my $res = $ua->request($req);

        my $content_string = substr $res->content,0,17;
        if ($res->code == 500 and ($content_string eq "500 Can't connect")) {
                print "[CRITICAL] Could not connect to server, please check your config or connection to the server.\n";
                print "[CRITICAL] Exiting\n\n";
                exit;
        }

	if (!($res->is_success)) {
                my $realm = $res->header("WWW-Authenticate");
                $realm = substr $realm, index($realm,'"') +1;
                $realm = substr $realm, 0, index($realm,'"');
                if ($res->code == 401 && (!($config->{realm} eq $realm)) ) {
                        $config->{realm} = $realm;
                        return get_file_from_uri($file,$uri,$accept_type);
                } else {
                        print "[CRITICAL] Operation Failed\n";
                        if ($debug) {
                                print $res->status_line;
                                print "\n";
                                print $res->content;
                        }
                        return undef;
                }
        }

        open(FILE,">$file");
        print FILE $res->content;
        close(FILE);
        return 1;

}

sub md5sum {
	my $file = shift;
	use Digest::MD5;
	my $digest = "";
	eval{
		open(FILE, $file) or die "[ERROR] md5sum: Can't find file $file\n";
		my $ctx = Digest::MD5->new;
		$ctx->addfile(*FILE);
		$digest = $ctx->hexdigest;
		close(FILE);
	};
	if($@){
		print $@;
		return "";
	}
	return $digest;
}

sub get_sword_uri_from_html {
	my $fh = shift;
	
	local $/;
	my $html = <$fh>;

	if( $html !~ /<link([^>]+)rel=\s*(["'])SwordDeposit\2\s*([^>]+)/ )
	{
		warn "no SwordDeposit link rel";
		return;
	}
	$html = $1.$3;
	if( $html !~ /\bhref=(["'])([^"']+)/ )
	{
		warn "no href found in SwordDeposit link rel";
		return;
	}

	return $2;
}

sub get_user_agent {

	my $ua = LWP::UserAgent->new();

	$ua->credentials(
			$config->{host},
			$config->{realm},
			$config->{username} => $config->{password}
			);

	return $ua;

}

sub create_container {

	my $filename = shift;
	my $filepath = shift; 
	my $no_op = shift;

	my $title = "placeholder";
	
	if (defined $filename && defined $filepath) 
	{
		$title = substr $filepath, 0, length($filepath) - length($filename);
		$title = substr $title, 0, length($title)-1;
		$title = substr $title, rindex($title, "/")+1, length($title);
	}

	my $content = '<?xml version="1.0" encoding="utf-8" ?>
<entry xmlns="http://www.w3.org/2005/Atom">
<title>' . $title . '</title>
</entry>
';
	
	my $url = $config->{sword_url};
	
	if ($debug) {
		if ($no_op) {
			print "[STARTUP] Attempting to establish deposit connection to server at $url\n";
		} else {
			print "[MESSAGE] Attempting to create resource container at $url\n";
		}
	}
	
	my $ua = get_user_agent();

	my $req = HTTP::Request->new( POST => $url );
	
	$req->content_type( "application/atom+xml" );
	if ($no_op) 
	{
		$req->header( 'X-No-Op' => 'true' );
	}
#	$req->header( 'X-Packaging' => 'http://www.w3.org/2005/Atom' );
	
	$req->content( $content );
	
	my $res = $ua->request($req);	

	if (!($res->is_success)) {
		my $res_code;
		my $realm = $res->header("WWW-Authenticate");
		if (defined $realm) {
		        $realm = substr $realm, index($realm,'"') +1;
        		$realm = substr $realm, 0, index($realm,'"');
		} 
		if ($res->code == 401 && (!($config->{realm} eq $realm)) ) {
			$config->{realm} = $realm;
			return create_container($filename,$filepath,$no_op);
		} else {
			if ($debug) {
				if ($no_op) {
					print "[STARTUP] Failed to create the container, trying alternatives...\n";
				} else {
					print "[CRITICAL] Failed to create the contatiner\n";
				}
				print $res->status_line;
				print "\n";
				print $res->content;
			}
			return undef;
		}
	}
	
	if ($res->is_success && $no_op) {
		return 1;
	}

	my $location_url = $res->header("Location");
	#$content = $res->content;
	#my ($location_uri,$media_uri,$edit_uri) = get_uris_from_atom($content);
	
	#if (defined $location_url) {
	#	$location_uri = $location_url;
	#}
	
	#write_parent_uris($filename,$filepath,$media_uri,$location_uri,$edit_uri);
	return $location_url;
	
}

sub deposit_file {
	
	my ($endpoint,$username,$password,$filepath,$url) = @_;
	
	if ($debug) { print "[MESSAGE] Attempting to post $filepath to $url\n"; }

	$config->{host} = $endpoint;
	$config->{username} = $username;
	$config->{password} = $password;
	unless (check_config()) {
		return "critical_incorrect_credentials";
	}

	my $filename = substr($filepath,rindex($filepath,"/")+1,length($filepath));
	my $suffix = substr($filename,rindex($filename,".")+1,length($filename));

	# Need to create a container to deposit into
	my $eprint_id_url;
	if (!defined $url) {
		$url = create_container($filename,$filepath);
		$eprint_id_url = $url;
		$url .= "/contents";
	}

	return undef if (!defined $url);

	open(FILE, "$filepath" ) or die("can't open input file");
	binmode FILE;

	my $ua = get_user_agent();

	my $req = HTTP::Request->new( POST => $url );

	if ($debug) {
		print "[MESSAGE] POSTING $filename to $url : $filepath user " . $config->{username} . "\n\n";
	}

	$req->header( 'Content-Disposition' => 'form-data; name="'.$filename.'"; filename="'.$filename.'"');
	$req->header( 'X-Extract-Media' => 'true' );
	$req->header( 'X-Override-Metadata' => 'true' );
#$req->header( 'X-Extract-Archive' => 'true' );

	$req->header( 'Content-Disposition' => 'form-data; name="'.$filename.'"; filename="'.$filename.'"');

	use MIME::Types qw(by_suffix by_mediatype);

	my ($mime_type,$encoding) = by_suffix($filepath);
	if ($suffix eq "epm") { $mime_type = "archive/zip+eprints_package"; }
	$req->content_type( $mime_type );

	my $file = "";
	while(<FILE>) { $file .= $_; }

	$req->content( $file );

	# Et Zzzzooo!
	my $res = $ua->request($req);	
	
	close(FILE);
	
	if (!($res->is_success)) {
		my $realm = $res->header("WWW-Authenticate");
	        if (defined $realm) {
			$realm = substr $realm, index($realm,'"') +1;
        		$realm = substr $realm, 0, index($realm,'"');
		}
		if ($res->code == 401 && (!($config->{realm} eq $realm)) ) {
			$config->{realm} = $realm;
			return deposit_file($filepath,$filename,$url); 
		} else {
			if ($debug) {
				print $url . "\n\n";
				print $config->{username};
				print "\n\n";
				print $config->{password};
				print "[CRITICAL] Failed to POST the FILE\n";
				print $res->status_line;
				print "\n";
				print $res->content;
			}
			return undef;
			
		}
	}
		
	if (defined $eprint_id_url) {
		return $eprint_id_url;
	}
	my $location_url = $res->header("Location");
	my $content = $res->content;
	return ($location_url);
	
}

sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

1;
