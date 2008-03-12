package EPrints::Plugin::Export;

use strict;

our @ISA = qw/ EPrints::Plugin /;

$EPrints::Plugin::Export::DISABLE = 1;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{name} = "Base output plugin: This should have been subclassed";
	$self->{suffix} = ".txt";
	$self->{visible} = "all";
	$self->{mimetype} = "text/plain";
	$self->{advertise} = 1;

	return $self;
}

sub render_name
{
	my( $plugin ) = @_;

	return $plugin->{session}->make_text( $plugin->param("name") );
}

sub matches 
{
	my( $self, $test, $param ) = @_;

	if( $test eq "is_feed" )
	{
		return( $self->is_feed() );
	}
	if( $test eq "is_visible" )
	{
		return( $self->is_visible( $param ) );
	}
	if( $test eq "can_accept" )
	{
		return( $self->can_accept( $param ) );
	}
	if( $test eq "has_xmlns" )
	{
		return( $self->has_xmlns( $param ) );
	}
	if( $test eq "is_advertised" )
	{
		return( $self->param( "advertise" ) == $param );
	}

	# didn't understand this match 
	return $self->SUPER::matches( $test, $param );
}

sub is_feed
{
	my( $self ) = @_;

	return 0;
}


# all, staff or ""
sub is_visible
{
	my( $plugin, $vis_level ) = @_;

	return( 1 ) unless( defined $vis_level );

	my $visible = $plugin->param("visible");
	return( 0 ) unless( defined $visible );

	if( $vis_level eq "all" && $visible ne "all" ) {
		return 0;
	}

	if( $vis_level eq "staff" && $visible ne "all" && $visible ne "staff" ) 
	{
		return 0;
	}

	return 1;
}

sub can_accept
{
	my( $plugin, $format ) = @_;

	my $accept = $plugin->param( "accept" );
	foreach my $a_format ( @{$accept} ) {
		if( $a_format =~ m/^(.*)\*$/ ) {
			my $base = $1;
			return( 1 ) if( substr( $format, 0, length $base ) eq $base );
		}
		else {
			return( 1 ) if( $format eq $a_format );
		}
	}

	return 0;
}

sub has_xmlns
{
	my( $plugin, $unused ) = @_;

	return 1 if( defined $plugin->param("xmlns") );
}


sub output_list
{
	my( $plugin, %opts ) = @_;

	my $r = [];
	foreach my $dataobj ( $opts{list}->get_records ) 
	{
		my $part = $plugin->output_dataobj( $dataobj, %opts );
		if( defined $opts{fh} )
		{
			print {$opts{fh}} $part;
		}
		else
		{
			push @{$r}, $part;
		}
	}	

	if( defined $opts{fh} )
	{
		return undef;
	}

	return join( '', @{$r} );
}

#stub.
sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;
	
	my $r = "error. output_dataobj not subclassed";

	$plugin->{session}->get_repository->log( $r );

	return $r;
}

sub xml_dataobj
{
	my( $plugin, $dataobj ) = @_;
	
	my $r = "error. xml_dataobj not subclassed";

	$plugin->{session}->get_repository->log( $r );

	return $plugin->{session}->make_text( $r );
}

# if this an output plugin can output results for a single dataobj then
# this routine returns a URL which will export it. This routine does not
# check that it's actually possible.
sub dataobj_export_url
{
	my( $plugin, $dataobj, $staff ) = @_;

	my $dataset = $dataobj->get_dataset;
	if( $dataset->confid ne "eprint" ) {
		# only know URLs for eprint objects
		return undef;
	}

	my $pluginid = $plugin->{id};

	unless( $pluginid =~ m#^Export::(.*)$# )
	{
		$plugin->{session}->get_repository->log( "Bad pluginid in dataobj_export_url: ".$pluginid );
		return undef;
	}
	my $format = $1;

	my $url = $plugin->{session}->get_repository->get_conf( "http_cgiurl" );
	$url .= "/users" if $staff;
	$url .= "/export/".$dataobj->get_id."/".$format;
	$url .= "/".$plugin->{session}->get_repository->get_id;
	$url .= "-".$dataobj->get_dataset->confid."-".$dataobj->get_id.$plugin->param("suffix");

	return $url;
}

sub byte_order_mark
{
	"";
}


1;
