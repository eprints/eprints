=for Pod2Wiki

=head1 NAME

EPrints::Plugin - base class of all EPrints Plugins

=head1 SYNOPSIS

	$plugin = $repo->plugin( "Export::XML" );

=head1 DESCRIPTION

This class provides the basic methods used by all EPrints Plugins.

=head1 METHODS

=over 4

=cut

package EPrints::Plugin;

use strict;

######################################################################
=pod

=item $plugin = EPrints::Plugin->new( %params );

Create a new instance of a plugin. Defines the following parameters:

=over 4

=item repository

Required handle to the current repository object.

=item name

Human-readable name of the plugin.

=item alias

Array reference of plugin id's that this plugin is aliasing (replacing).

=back

=cut
######################################################################

sub new
{
	my( $class, %params ) = @_;

	$params{repository} = $params{session} ||= $params{repository};

	if( !exists $params{id} )
	{
		$class =~ /^(?:EPrints::Plugin::)?(.*)$/;
		$params{id} = $1;
	}

	$params{name} = exists $params{name} ? $params{name} : $params{id} . " plugin is missing the name parameter";
	# aliases for this plugin (allows overriding of core plugins)
	$params{alias} = exists $params{alias} ? $params{alias} : [];

	return bless \%params, $class;
}

*get_repository = \&repository;
sub repository
{
	my( $self ) = @_;

	return $self->{repository};
}

=item $mime_type = EPrints::Plugin->mime_type()

Returns the MIME type for this plugin.

Returns undef if there is no relevant MIME type for this plugin type.

=cut

sub mime_type
{
	my( $class ) = @_;

	my $mime_type = substr(lc(ref($class) || $class), 17);
	$mime_type =~ s/::/-/g;
	$mime_type = "application/x-eprints-$mime_type";

	return $mime_type;
}

######################################################################
=pod

=item $value = EPrints::Plugin->local_uri

Return a unique ID for this plugin as it relates to the current 
repository. This can be used to distinguish that XML import for 
different repositories may have minor differences.

This URL will not resolve to anything useful.

=cut
######################################################################

sub local_uri
{
	my( $self ) = @_;

	my $id = $self->{id};
	$id =~ s!::!/!g;
	return $self->{repository}->config( "http_url" )."/#Plugin/".$id;
}

######################################################################
=pod

=item $value = EPrints::Plugin->global_uri

Return a unique ID for this plugin, but not just in this repository
but for any repository. This can be used for fuzzier tools which do
not care about the minor differences between EPrints repositories.

This URL will not resolve to anything useful.

=cut
######################################################################

sub global_uri
{
	my( $self ) = @_;

	my $id = $self->{id};
	$id =~ s!::!/!g;
	return "http://eprints.org/eprints3/#Plugin/".$id;
}

######################################################################
=pod

=item $id = $plugin->get_id

Return the ID of this plugin.

=cut
######################################################################

sub get_id
{
	my( $self ) = @_;

	return $self->{id};
}

######################################################################
=pod

=item $name = $plugin->get_name

Return the ID of this plugin.

=cut
######################################################################

sub get_name
{
	my( $self ) = @_;

	return $self->{name};
}

######################################################################
=pod

=item $name = $plugin->get_type

Return the type of this plugin. eg. Export

=cut
######################################################################

sub get_type
{
	my( $self ) = @_;

	$self->{id} =~ m/^([^:]*)/;

	return $1;
}

######################################################################
=pod

=item $name = $plugin->get_subtype

Return the sub-type of this plugin. eg. BibTex

This is the ID with the type stripped from the front.

=cut
######################################################################

sub get_subtype
{
	my( $self ) = @_;

	$self->{id} =~ m/^[^:]*::(.*)/;

	return $1;
}

######################################################################
=pod

=item $msg = $plugin->error_message

Return the error message, if this plugin can't be used.

=cut
######################################################################

sub error_message
{
	my( $self ) = @_;

	return $self->{error};
}


######################################################################
=pod

=item $boolean = $plugin->broken

Return the value of a parameter in the current plugin.

=cut
######################################################################

sub broken
{
	my( $self ) = @_;

	return defined $self->{error};
}


######################################################################
=pod

=item $name = $plugin->matches( $test, $param )

Return true if this plugin matches the test, false otherwise. If the
test is not known then return false.

=cut
######################################################################

sub matches 
{
	my( $self, $test, $param ) = @_;

	if( $test eq "type" )
	{
		my $l = length( $param );
		my $start = substr( $self->{id}, 0, $l );
		return( $start eq $param );
	}

	# didn't understand this match 
	return 0;
}

######################################################################
=pod

=item $value = $plugin->param( $paramid )

Return the parameter with the given id. This uses the hard wired
parameter unless an override has been configured for this repository:

	$c->{plugins}->{"Export::XML"}->{params}->{name} = "My EP3 XML";
	$c->{plugins}->{"Export::Ids"}->{params}->{disable} = 1;

=cut
######################################################################

sub param 
{
	my( $self, $paramid ) = @_;

	my $pconf = $self->{repository}->config( "plugins", $self->{id} );

	if( defined $pconf->{params} && exists $pconf->{params}->{$paramid} )
	{
		return $pconf->{params}->{$paramid};
	}

	return $self->{$paramid};
}

######################################################################
=pod

=item $phraseid = $plugin->html_phrase_id( $id )

Returns the fully-qualified phrase identifier for the $id phrase for this
plugin.

=cut
######################################################################

sub html_phrase_id 
{
	my( $self, $id ) = @_;

	my $base = "Plugin/".$self->{id};
	$base =~ s/::/\//g;

	return $base . ':' . $id;
}

######################################################################
=pod

=item $xhtml = $plugin->html_phrase( $id, %bits )

Return the phrase belonging to this plugin, with the given id.

Returns a DOM tree.

=cut
######################################################################

sub html_phrase 
{
	my( $self, $id, %bits ) = @_;

#	my $base = substr( caller(0), 9 );
	my $base = "Plugin/".$self->{id};
	$base =~ s/::/\//g;

	return $self->{repository}->html_phrase( $base.":".$id, %bits );
}

######################################################################
=item $url = $plugin->icon_url

Returns the relative URL to the icon for this plugin.

=cut
######################################################################

sub icon_url
{
	my( $self ) = @_;

	my $icon = $self->{repository}->config( "plugins", $self->{id}, "icon" );
	if( !defined( $icon ) )
	{
		$icon = $self->{icon};
	}

	return undef if !defined $icon;

	my $url = $self->{repository}->get_url( path => "images", $icon );

	return $url;
}

######################################################################
=pod

=item $utf8 = $plugin->phrase( $id, %bits )

Return the phrase belonging to this plugin, with the given id.

Returns a utf-8 encoded string.

=cut
######################################################################

sub phrase 
{
	my( $self, $id, %bits ) = @_;

	#my $base = substr( caller(0), 9 );
	my $base = "Plugin/".$self->{id};
	$base =~ s/::/\//g;

	return $self->{repository}->phrase( $base.":".$id, %bits );
}


1;

######################################################################
=pod

=back

=cut
######################################################################


=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

