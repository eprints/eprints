=for Pod2Wiki

=head1 NAME

EPrints::Plugin::Screen - dynamic user interface web pages

=head1 DESCRIPTION

Screen plugins provide the CGI user interface to EPrints. Only "static" pages (summary pages, browse views) are not rendered via screens.

Screens generate elements of the page that are then rendered using the L<EPrints::Apache::Template>. These elements include the page title, header elements and page body. Screens can also B<export> (depending on L</wishes_to_export>) which allows complete control over the HTTP response.

Most screens have an interactive element that follow this pattern:

first request ...

=over 4

=item 1. can_be_viewed() grants access

=item 2. properties_from() sets up the response

=item 3. render() includes a form with an action

=back

second request ...

=over 4

=item 4. properties_from() sets up the response

=item 5. from() identifies the action

=item 6. allow_*() checks access to the specific action

=item 7. action_*() method performs the (probably) side-effecting action

=item 8. redirect_to_me_url() redirects the user back to ...

=back

third request ... back to step 1.

The exception to this is where L</redirect_to_me_url> is sub-classed to return undef, in which case the screen is expected to render in addition to processing the form request.

The reason for using a redirect is that the user will end up on a page that can be reloaded without re-submitting the form. This is particularly important where submitting the action twice may result in an error, for example when deleting an object (can't delete twice!). 

=head1 PARAMETERS

=head2 action_icon

	$self->{action_icon} = {
		move_archive => "action_approve.png",
		review_move_archive => "action_approve.png",
	};

Use an icon instead of a button for the given actions. The image name is relative to F<style/images/>.

=head2 actions

	$self->{actions} = [qw( clear update cancel )];

A list of actions that are supported by this screen.

=head2 appears

	$self->{appears} = [
		place => "eprint_summary_page_actions",
		position => 100,
	];

Controls where links/buttons to this plugin will appear.

=over 4

=item place

The string-constant name of the list to appear in. Other plugins will refer to this via the L</list_items> and related methods.

=item position

The relative position in the list to appear at. Higher means later in the list.

=item action

The optional action that this button will trigger.

=back

=head2 icon

	$self->{icon} = "action_view.png";

Use an icon instead of a button for links to this screen. The image name is relative to F<style/images/>.

=head1 METHODS

=over 4

=cut

package EPrints::Plugin::Screen;

# Top level screen.
# Abstract.
# 

use strict;

our @ISA = qw/ EPrints::Plugin /;

our $CSRF_KEY = "_CSRF_Token";

sub new
{
	my( $class, %params ) = @_;

	$params{actions} = exists $params{actions} ? $params{actions} : [];
	$params{session} = exists $params{session} ? $params{session} : $params{processor}->{session};

	# flag to indicate that it takes some effort to make this screen, so
	# don't make it up as a tab. eg. EPrint::History.
	$params{expensive} = exists $params{expensive} ? $params{expensive} : 0; 

	return $class->SUPER::new(%params);
}

=item $screen->properties_from()

Called by the L<EPrints::ScreenProcessor> very early in the response process.

This method should be used to set up the response by, for example getting CGI query parameters and storing them in the processor object.

Because this method is called B<before> L</can_be_viewed> no changes to the system should be made here.

=cut

sub properties_from
{
	my( $self ) = @_;

}

=item $url = $screen->redirect_to_me_url()

If the request is a POST the screen is given an opportunity to redirect the user, avoiding double-POSTs if the user reloads the resulting page.

=cut

sub redirect_to_me_url
{
	my( $self ) = @_;

	return $self->{processor}->{url}."?screen=".$self->{processor}->{screenid};
}

=item $xhtml = $screen->render()

Render the page body.

=cut

sub render
{
	my( $self ) = @_;

	my $phraseid = substr(__PACKAGE__, 9);
	$phraseid =~ s/::/\//g;
	$phraseid .= ":no_render_subclass";

	return $self->{session}->html_phrase( $phraseid, screen => $self->{session}->make_text( $self ) );
}

=item $xhtml = $screen->render_links()

Render any elements for the page <head> section.

=cut

sub render_links
{
	my( $self ) = @_;

	return $self->{session}->make_doc_fragment;
}

sub register_furniture
{
	my( $self ) = @_;

	return $self->{session}->make_doc_fragment;
}

sub register_error
{
	my( $self ) = @_;

	$self->{processor}->add_message( "error", $self->{session}->html_phrase( 
		"Plugin/Screen:screen_not_allowed",
		screen=>$self->{session}->make_text( $self->{processor}->{screenid} ) ) );
}

=item @params = $screen->hidden_bits()

Returns a key-value list of values that must be set when referring to this screen.

At the top-level this is just the 'screen' id.

Historically render_hidden_bits() - which built up a set of hidden inputs in XHTML - was used but this had the downside of not being usable with GET requests. Screen plugins now have a mix of approaches, so care is needed when sub-classing C<hidden_bits>.

=cut

sub hidden_bits
{
	my( $self ) = @_;

	return(
		screen => $self->get_subtype
	);
}

sub render_hidden_bits
{
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;

	my @params = $self->hidden_bits;
	for(my $i = 0; $i < @params; $i+=2)
	{
		$chunk->appendChild( $self->{session}->render_hidden_field( 
				@params[$i,$i+1]
			) );
	}

	return $chunk;
}

=item $bool = $screen->wishes_to_export()

If true, instead of calling the render* methods the export* methods will be used.

=cut

sub wishes_to_export
{
	my( $self ) = @_;

	return 0;
}

=item $screen->export()

Called when L</wishes_to_export> is true.

This method should generate an HTTP response directly (e.g. by printing to STDOUT).

=cut

sub export
{
	my( $self ) = @_;

	print "Needs to be subclassed\n";
}

=item $mime_type = $screen->export_mimetype()

Return the MIME type of the HTTP response (as will be generated by L</export>).

Default is to use "text/plain".

=cut

sub export_mimetype
{
	my( $self ) = @_;

	return "text/plain";
}

=item $xhtml = $screen->render_form( [ METHOD [, ACTION ] ] )

Render an XHTML form that will call this screen. If the METHOD is POST will apply cross-site request forgery protection.

Unless you have a good reason not to you should always use render_form() to add forms to your HTTP response, which ensures the correct context and request protections are in place.

=cut

sub render_form
{
	my( $self, $method, $action ) = @_;

	$method = "post" if !defined $method;
	$action = $self->{processor}->{url} . "#t" if !defined $action;

	my $form = $self->{session}->xhtml->form( $method, $action );

	$form->appendChild( $self->render_hidden_bits );

	if( lc($method) eq "post" )
	{
		my $csrf = $self->csrf;
		$csrf = $self->set_csrf if !defined $csrf;

		$form->appendChild( $self->{session}->xhtml->hidden_field( $CSRF_KEY, $csrf ) );
	}

	return $form;
}

=begin InternalDoc

=item $csrf = $screen->csrf

Returns the CSRF cookie value.

=end InternalDoc

=cut

sub csrf
{
	my( $self ) = @_;

	# cached from a previous set_csrf() call
	return $self->{processor}->{csrf} if defined $self->{processor}->{csrf};

	return $self->repository->get_secure ?
		EPrints::Cookie::cookie( $self->repository, "eprints_secure_csrf" ) :
		EPrints::Cookie::cookie( $self->repository, "eprints_csrf" );
}

=begin InternalDoc

=item $csrf = $screen->set_csrf

Generate and set a new CSRF code. Returns the new code.

=end InternalDoc

=cut

sub set_csrf
{
	my( $self ) = @_;

	my $csrf = $self->{processor}->{csrf} = &EPrints::DataObj::LoginTicket::_code;

	# note: someone with control of the wire could sniff the insecure cookie
	# then rewrite an insecure page with a call to the HTTPS page, hence we use
	# different cookies/codes for HTTP and HTTPS
	if( $self->repository->get_secure )
	{
		EPrints::Cookie::set_secure_cookie( $self->repository, "eprints_secure_csrf", $csrf );
	}
	else
	{
		EPrints::Cookie::set_cookie( $self->repository, "eprints_csrf", $csrf );
	}

	return $csrf;
}

sub about_to_render 
{
	my( $self ) = @_;
}

sub obtain_edit_lock
{
	my( $self ) = @_;

	return $self->obtain_lock;
}

sub obtain_view_lock
{
	my( $self ) = @_;

	return $self->obtain_lock;
}

sub obtain_lock
{
	my( $self ) = @_;
	
	return 1;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 1;
}

sub allow_action
{
	my( $self, $action_id ) = @_;

	my $fn = "allow_".$action_id;
	return $self->$fn;
}

=item $ok = $screen->verify_csrf()

Verify that the CSRF token in the user agent's cookie matches the token passed in the form value.

If the CSRF check fails no action should be taken as this may be an attempt to forge a request.

=cut

sub verify_csrf
{
	my( $self ) = @_;

	my $cookie = $self->csrf;
	my $param = $self->repository->param( $CSRF_KEY );

	if( !$cookie || !$param || $cookie ne $param )
	{
		return 0;
	}

	return 1;
}

sub render_tab_title
{
	my( $self ) = @_;

	return $self->render_title;
}

sub from
{
	my( $self ) = @_;

	my $action_id = $self->{processor}->{action};

	# _action_null is legacy
	return if( !defined $action_id || $action_id eq "" || $action_id eq "null" );

	# If you hit reload after login you can cause a
	# login action, so we'll just ignore it.
#	return if( $action_id eq "login" );

	if( !$self->has_action( $action_id ) )
	{
		$self->{processor}->add_message( "error",
			$self->{session}->html_phrase( 
	      			"Plugin/Screen:unknown_action",
				action=>$self->{session}->make_text( $action_id ),
				screen=>$self->{session}->make_text( $self->{processor}->{screenid} ) ) );
	}
	elsif( !$self->allow_action( $action_id ) )
	{
		$self->{processor}->action_not_allowed( 
			$self->html_phrase( "action:$action_id:title" ) );
	}
	elsif( !$self->verify_csrf )
	{
		$self->{processor}->add_message( "error", $self->repository->html_phrase(
				"Plugin/Screen:csrf_failure"
			) );
	}
	else
	{
		my $fn = "action_".$action_id;
		$self->$fn;
	}
}

sub allow
{
	my( $self, $priv, $dataobj ) = @_;

	return 1 if( $self->{session}->allow_anybody( $priv, $dataobj ) );
	return 0 if( !defined $self->{session}->current_user );
	return $self->{session}->current_user->allow( $priv, $dataobj );
}


# these methods all could be properties really


sub matches 
{
	my( $self, $test, $param ) = @_;

	return $self->SUPER::matches( $test, $param );
}

=item $xhtml = $screen->render_title

Render the page title.

=cut

sub render_title
{
	my( $self ) = @_;

	return $self->html_phrase( "title" );
}

=item @screen_opts = $screen->list_items( $list_id, %opts )

Returns a list of screens that appear in list $list_id ordered by their position.

Each screen opt is a hash ref of:

	screen - screen plugin
	screen_id - screen id
	position - position (positive integer)
	action - the action, if this plugin is for an action list

Incoming opts:

	filter => 1 or 0 (default 1)
	params => {}

=cut

sub list_items
{
	my( $self, $list_id, %opts ) = @_;

	return $self->{processor}->list_items( $list_id, %opts );
}	

=item $ok = $screen->has_action( $action_id )

Returns true if this screen has an action $action_id.

=cut

sub has_action
{
	my( $self, $action_id ) = @_;

	for(@{$self->{actions}})
	{
		return 1 if $action_id eq $_;
	}

	return 0;
}

sub action_allowed
{
	my( $self, $item ) = @_;
	my $who_allowed;
	if( defined $item->{action} )
	{
 		$who_allowed = $item->{screen}->allow_action( $item->{action} );
	}
	else
	{
		$who_allowed = $item->{screen}->can_be_viewed;
	}

	return 0 unless( $who_allowed & $self->who_filter );
	return 1;
}

sub action_list
{
	my( $self, $list_id ) = @_;

	my @list = ();
	foreach my $item ( $self->list_items( $list_id ) )
	{
		next unless $self->action_allowed( $item );

		push @list, $item;
	}

	return @list;
}


sub who_filter { return 255; }

sub get_description
{
	my( $self, $params ) = @_;
	my $description;
	if( defined $params->{action} )
	{
		my $action = $params->{action};
		$description = $params->{screen}->html_phrase( "action:$action:description" );
	}
	else
	{
		$description = $params->{screen}->html_phrase( "description" );
	}
	return $description;
}

=item $url = $screen->action_icon_url( $action )

Returns the relative URL to the $action icon for this screen.

=cut

sub action_icon_url
{
	my( $self, $action ) = @_;

	my $icon = $self->{session}->get_repository->get_conf( "plugins", $self->{id}, "actions", $action, "icon" );
	if( !defined $icon ) 
	{
		$icon = $self->{action_icon}->{$action};
	}

	return undef if !defined $icon;

	my $url = $self->{session}->get_url( path => "images", $icon );

	return $url;
}

=item $frag = $screen->render_action_link()

Returns a link to this screen.

=cut

sub render_action_link
{
	my( $self, %opts ) = @_;

	my $uri = URI->new( $self->{session}->config( "http_cgiurl" ) . "/users/home" );
	$uri->query_form(
		screen => substr($self->{id},8),
	);

	my $link = $self->{session}->render_link( $uri );
	$link->appendChild( $self->render_title );

	return $link;
}

sub render_action_icon
{
	my( $self, $params ) = @_;

	return $self->_render_action_aux( $params, 1 );
}

sub render_action_button
{
	my( $self, $params ) = @_;

	return $self->_render_action_aux( $params, 0 );
}

sub _render_action_aux
{
	my( $self, $params, $asicon ) = @_;
	
	my $session = $self->{session};
	
	my @query = (
			screen => $params->{screen}->get_subtype,
		);

	my $method = "get";	
	if( defined $params->{action} )
	{
		$method = "post";
		my $csrf = $self->csrf;
		$csrf = $self->set_csrf if !defined $csrf;
		push @query, $CSRF_KEY => $csrf;
	}

	my $hidden = $params->{hidden};
	if( ref($hidden) eq "ARRAY" )
	{
		foreach my $id ( @$hidden )
		{
			push @query, $id => $self->{processor}->{$id};
		}
	}
	else
	{
		foreach my $id (keys %$hidden)
		{
			push @query, $id => $hidden->{$id};
		}
	}
	my( $action, $title, $icon );
	if( defined $params->{action} )
	{
		$action = $params->{action};
		$title = $params->{screen}->phrase( "action:$action:title" );
		$icon = $params->{screen}->action_icon_url( $action );
	}
	else
	{
		$action = "";
		$title = $params->{screen}->phrase( "title" );
		$icon = $params->{screen}->icon_url();
	}
	
	my $path = $session->current_url( path => "cgi" ) . "/users/home";

	my $frag;

	if( $method eq "get" && defined $icon && $asicon )
	{
		push @query, "_action_$action" => 1 if length($action);
		my $uri = URI->new( $path );
		$uri->query_form( @query );
		$frag = $session->render_link( $uri );
		if( defined $icon && $asicon )
		{
			$frag->appendChild( $session->make_element( "img",
				src=>$icon,
				title=>$title,
				alt=>$title,
				class=>"ep_form_action_icon",
			) );
		}
		# never called because mixing <input> and <href> is ugly
		else
		{
			$frag->setAttribute( class => "ep_form_action_button" );
			$frag->appendChild( $session->make_text( $title ) );
		}
	}
	else
	{
		$frag = $session->render_form( $method, $path );
		foreach my $i (0..$#query)
		{
			next if $i % 2;
			$frag->appendChild( $session->render_hidden_field( 
				@query[$i, $i+1] ) );
		}
		if( defined $icon && $asicon )
		{
			$frag->appendChild( 
				$session->make_element(
					"input",
					type=>"image",
					class=>"ep_form_action_icon",
					($action ? (name=>"_action_$action") : ()),
					src=>$icon,
					title=>$title,
					alt=>$title,
					value=>$title ));
		}
		else
		{
			$frag->appendChild( 
				$session->render_button(
					class=>"ep_form_action_button",
					($action ? (name=>"_action_$action") : ()),
					value=>$title ));
		}
	}

	return $frag;
}

sub render_action_button_if_allowed
{
	my( $self, $params, $hidden ) = @_;

	if( $self->action_allowed( $params ) )
	{
		return $self->render_action_button( { %$params, hidden => $hidden } ); 
	}
	else
	{
		return $self->{session}->make_doc_fragment;
	}
}

sub render_action_list
{
	my( $self, $list_id, $hidden ) = @_;

	my $repo = $self->repository;

	my( @actions, @definitions );
	foreach my $params ($self->action_list( $list_id ))
	{
		push @actions, $self->render_action_button( { %$params, hidden => $hidden } );
		push @definitions, $self->get_description( $params );
	}

	return $repo->xhtml->action_definition_list( \@actions, \@definitions );
}


sub render_action_list_bar
{
	my( $self, $list_id, $hidden ) = @_;

	my $repo = $self->repository;

	my @actions;
	foreach my $params ($self->action_list( $list_id ))
	{
		push @actions, $self->render_action_button( { %$params, hidden => $hidden } );
	}

	my $div = $repo->xml->create_element( "div", class => "ep_block" );
	$div->appendChild( $repo->xhtml->action_list( \@actions ) );

	return $div;
}


sub render_action_list_icons
{
	my( $self, $list_id, $hidden ) = @_;

	my $repo = $self->repository;

	my @actions;
	foreach my $params ($self->action_list( $list_id ))
	{
		push @actions, $self->render_action_icon( { %$params, hidden => $hidden } );
	}

	return $repo->xhtml->action_list( \@actions );
}

1;

		
=back	

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2013 University of Southampton.

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

