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
	];
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

	if( !$item->is_set( "newemail" ) && $attr{'value.email'} )
	{
		$item->set_value( "newemail", $attr{'value.email'} );
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
		$processor->add_message( "error", $self->{session}->html_phrase(
			"lib/eprint:not_done_field" ,
			fieldname=>$item->{dataset}->field( "openid_identifier" )->render_name( $repo ) ) );
		return;
	}

	my $plugin = $repo->plugin( "Screen::Login::OpenID",
		processor => $processor,
		);
	my $dataset = $repo->dataset( "user" );

	my %args;
	foreach my $field ( $dataset->fields )
	{
		next if !$item->is_set( $field->name );
		$args{$field->name} = $field->get_id_from_value( $repo, $field->get_value( $item ) );
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

	return 1;
}

1;
