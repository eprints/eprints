######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

=head1 NAME

B<EPrints::Test::OnlineSession> - Test online features of EPrints, offline

=head1 METHODS

=over 4

=cut

package EPrints::Test::OnlineSession;

use EPrints::Test::RequestRec;

our @ISA = qw( EPrints::Session );

my @VARS = qw( stdout uri secure );
my %VAR;

=item $session = EPrints::Test::OnlineSession->new( $session, $query )

Subclass $session and initialise it with our fake $query.

$query may contain:

	method - either "GET" or "POST"
	path - path below $base_url
	query - query to append (string or hash ref)
	username - set current user to username
	secure - set to true to emulate HTTPS

=cut

foreach my $f (@VARS)
{
	my $fn = "test_get_$f";
	*$fn = sub { my( $self ) = @_; $VAR{$self}->{$f} };
}

sub new
{
	my( $class, $session, $opts ) = @_;

	my $self = bless $session, $class;

	my $method = $opts->{method} || "GET";
	my $path = defined $opts->{path} ? $opts->{path} : "";
	my $query = defined $opts->{query} ? $opts->{query} : "";

	my $uri = URI->new( $session->get_repository->get_conf( "base_url" ) );
	if( $path !~ m#^/# )
	{
		$path = $uri->path . "/" . $path;
	}
	$uri->path( $path );
	if( ref($query) eq "HASH" )
	{
		$uri->query_form( %$query );
	}
	elsif( length($query) )
	{
		$uri->query( $query );
	}

	$VAR{$self}->{uri} = $uri;
	$VAR{$self}->{secure} = $opts->{secure};

	my $cgi = CGI->new( $uri->query );
	$self->{query} = $cgi;
	$self->{offline} = 0;

	$self->{request} = EPrints::Test::RequestRec->new( uri => $uri->path );

	$ENV{REQUEST_METHOD} = $method;

	if( defined $opts->{username} )
	{
		my $user = EPrints::DataObj::User::user_with_username( $self, $opts->{username} );
		if( !defined $user )
		{
			EPrints::abort "Couldn't retrieve user with username $opts->{username}";
		}
		$self->{current_user} = $user;
	}

	return $self;
}

sub get_secure
{
	$VAR{$_[0]}->{secure};
}

sub get_uri
{
	my $uri = URI->new( $VAR{$_[0]}->{uri} );
	$uri->query( "" );
	return $uri;
}

sub get_full_url
{
	$VAR{$_[0]}->{uri};
}

sub current_user
{
	$_[0]->{current_user};
}

# Not sure how to deal with this?
sub get_static_page_conf_file
{
	undef;
}

sub send_http_header
{
#	Test::More::diag( "send_http_header()" );
}

sub send_page
{
	my( $self, %httpopts ) = @_;

#	Test::More::diag( "send_page()" );
	$VAR{$self}->{"stdout"} .= <<END;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
END
	if( $self->{page}->isa( "EPrints::Page::Text" ) )
	{
		$VAR{$self}->{"stdout"} .= $self->{page}->{page_text};
		delete $self->{page};
	}
	else
	{
		$VAR{$self}->{"stdout"} .= EPrints::XML::to_string( $self->{page}->{page_dom}, undef, 1 );
		delete $self->{page};
	}
}

1;
