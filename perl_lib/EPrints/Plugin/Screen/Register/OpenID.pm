=head1 NAME

EPrints::Plugin::Screen::Register::OpenID

=cut

package EPrints::Plugin::Screen::Register::OpenID;

use LWP::UserAgent;

@ISA = qw( EPrints::Plugin::Screen::Register );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{appears} = [
		{
			place => "register_tabs",
			position => 1000,
		},
		{
			place => "register_tools",
			position => 1000,
		},
	];
	$self->{endpoints} = [{
			# No permission to re-use Google's logo:
			# http://www.google.com/support/forum/p/apps-apis/thread?tid=37119cb988edbb78&hl=en
			url => "https://www.google.com/accounts/o8/id",
			title => "Google",
		},{
			# http://developer.yahoo.com/openid/faq.html
			url => "https://me.yahoo.com/",
			icon_url => "images/external/openid-yahoo.png",
			title => "Yahoo",
		}];
	push @{$self->{actions}}, qw( return );

	return $self;
}

sub allow_return { return shift->allow_register() }

# fill in missing item values from OpenID extended attributes
sub update_from_ax
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $repo = $self->{repository};

	my %attr = EPrints::DataObj::OpenID->retrieve_attributes( $repo );

	my $item = $processor->{item};

	if( !$item->is_set( "email" ) && $attr{'value.email'} )
	{
		$item->set_value( "email", $attr{'value.email'} );
	}
	if( !$item->is_set( "name" ) && $attr{'value.lastname'} )
	{
		$item->set_value( "name", {
			given => $attr{'value.firstname'},
			family => $attr{'value.lastname'},
		});
	}
}

sub action_register
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $repo = $self->{repository};

	$processor->{screenid} = 'Register';

	my $item = $processor->{item};

	my $workflow = $self->workflow;

	$workflow->update_from_form( $processor, $workflow->get_stage_id, 1 );

	if( !$item->is_set( "openid_identifier" ) )
	{
		if( $repo->param( "openid_identifier" ) )
		{
			$item->set_value( "openid_identifier", $repo->param( "openid_identifier" ) );
		}
		else
		{
			$processor->add_message( "error", $self->{session}->html_phrase(
				"lib/eprint:not_done_field" ,
				fieldname=>$item->{dataset}->field( "openid_identifier" )->render_name( $repo ) ) );
			return;
		}
	}

	my $plugin = $repo->plugin( "Screen::Login::OpenID",
		processor => $processor,
		);
	my $dataset = $repo->dataset( "user" );

	my %args;
	foreach my $param ($repo->param)
	{
		next if $param =~ /^_/;
		$args{$param} = $repo->param( $param );
	}
	$args{screen} = $self->get_subtype;
	$args{_action_return} = 1;

	my $return_to = URI->new( $repo->current_url( scheme => "http", host => 1 ) );
	$return_to->query_form( %args );

	# this causes a redirect
	$plugin->_init_openid( $item->value( "openid_identifier" ),
		'openid.return_to' => "$return_to",
		'openid.ns.ax' => 'http://openid.net/srv/ax/1.0',
		'openid.ax.mode' => 'fetch_request',
		'openid.ax.required' => 'email,firstname,lastname',
		'openid.ax.type.email' => 'http://axschema.org/contact/email',
		'openid.ax.type.firstname' => 'http://axschema.org/namePerson/first',
		'openid.ax.type.lastname' => 'http://axschema.org/namePerson/last',
	);
}

sub action_return
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $repo = $self->{repository};

	$processor->{screenid} = 'Register';
	$processor->{show} = $self->get_subtype;

	my $item = $processor->{item};

	my $mode = $repo->param( 'openid.mode' );
	$mode = '' if !defined $mode;

	if( $mode eq 'cancel' )
	{
		$repo->redirect( $repo->current_url( host => 1 ) );
		exit(0);
	}

	my $workflow = $self->workflow;

	$workflow->update_from_form( $processor, $workflow->get_stage_id, 1 );

	# action links aren't prefixed
	if( !$item->is_set( "openid_identifier" ) )
	{
		$item->set_value( "openid_identifier", $repo->param( "openid_identifier" ) );
	}

	$self->update_from_ax();

	my $plugin = $repo->plugin( "Screen::Login::OpenID",
		processor => $processor,
		);
	my $dataset = $repo->dataset( "user" );

	my $identity = $plugin->_valid_openid();
	return if !$identity;

	if( defined EPrints::DataObj::User::user_with_username( $repo, $identity ) )
	{
		$processor->add_message( "error", $repo->html_phrase(
			"cgi/register:username_exists", 
			username=>$repo->make_text( $identity ) ) );
		return;
	}

	$item->set_value( "openid_identifier", $identity );
	$item->set_value( "username", $identity );

	my @problems = $workflow->validate();
	if( @problems )
	{
		# change the openid back to the original submitted value, otherwise
		# we're asking the user to sign in with their assigned id rather than
		# the endpoint (should they be different)
		$item->set_value( "openid_identifier", $repo->param( "openid_identifier" ) );

		my $error = $repo->xml->create_element( "ul" );
		foreach my $problem (@problems)
		{
			$error->appendChild( $repo->xml->create_element( "li" ))
				->appendChild( $problem );
		}
		$processor->add_message( "error", $error );
		return;
	}

	my $user = $self->register_user( $item->get_data );

	$processor->{user} = $user;
	$processor->{action} = "register";

	return 1;
}

sub render
{
	my( $self ) = @_;

	return $self->SUPER::render_workflow();
}

sub render_action_link
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $repo = $self->{repository};
	my $xml = $repo->xml;

	my $frag = $xml->create_document_fragment;

	my $endpoints = $self->param( "endpoints" );
	my $base_url = URI->new( $repo->current_url() );
	$base_url->query_form(
		screen => $self->get_subtype,
		_action_register => 1,
		);
	foreach my $endpoint( @$endpoints )
	{
		my $url = $base_url->clone;
		$url->query_form(
			$url->query_form,
			openid_identifier => $endpoint->{url},
			);
		my $link = $xml->create_element( "a", href => "$url" );
		$frag->appendChild( $link );
		if( $endpoint->{icon_url} )
		{
			$link->appendChild( $xml->create_element( "img",
				src => $repo->current_url( path => "static", $endpoint->{icon_url} ),
				alt => $endpoint->{title},
				title => $endpoint->{title},
				border => 0,
				) );
		}
		else
		{
			$link->appendChild( $xml->create_text_node( $endpoint->{title} ) );
		}
	}

	return $frag;
}

1;

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

