=head1 NAME

EPrints::Plugin::Screen::Admin::EPM::Publish

=cut

package EPrints::Plugin::Screen::Admin::EPM::Publish;

use EPrints::Plugin::Screen::Workflow;
@ISA = ( 'EPrints::Plugin::Screen::Workflow' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ publish cancel /];
		
	$self->{appears} = [];

	return $self;
}

sub can_be_viewed { shift->EPrints::Plugin::Screen::Admin::EPM::can_be_viewed( @_ ) }
sub allow_publish { shift->can_be_viewed( @_ ) }
sub allow_cancel { shift->can_be_viewed( @_ ) }

sub properties_from
{
	shift->EPrints::Plugin::Screen::Admin::EPM::properties_from();
}

sub action_cancel
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "Admin::EPM";
}

sub action_publish
{
	my( $self ) = @_;

	my $epm = $self->{processor}->{dataobj};

	my $source = $self->{repository}->param( "source" );

	# locate the SWORD deposit endpoint
	my $ua = LWP::UserAgent->new;
	my $r = $ua->get( $source );
	if(
		$r->content !~ /(<link[^>]+rel=["']SwordDeposit[^>]+)>/i ||
		$1 !~ /href=["']([^"']+)/
	  )
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "bad_endpoint",
			base_url => $self->{repository}->xml->create_text_node( $source )
		) );
		return;
	}
	$source = $1;

	my $uri = $epm->publish( $self->{processor}, $source,
		username => scalar($self->{repository}->param( "username" )),
		password => scalar($self->{repository}->param( "password" ))
	);

	if( defined($uri) )
	{
		$self->{processor}->add_message( "message", $self->html_phrase( "success",
			uri => $self->{repository}->xml->create_data_element( "a", $uri, href => $uri )
			) );
	}

	$self->{processor}->{screenid} = 'Admin::EPM';
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my @q;

	for(qw( source username ))
	{
		push @q, $_ => scalar($repo->param( $_ ))
			if $repo->param( $_ );
	}
	my $uri = URI->new( $self->SUPER::redirect_to_me_url );
	$uri->query_form(
		$uri->query_form,
		@q
	) if @q;

	return "$uri";
}

sub render
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $xhtml = $repo->xhtml;
	my $xml = $repo->xml;

	my $sources = $self->{processor}->{sources};

	my $epm = $self->{processor}->{dataobj};

	my $frag = $xml->create_document_fragment;

	$frag->appendChild( $epm->render_citation );
	$frag->appendChild( $xml->create_element( "div", style => "clear: left" ) );

	my $form = $self->render_form;
	$frag->appendChild( $form );

	my $table = $form->appendChild( $xml->create_element( "table" ) );

	my $select = $xml->create_element( "select",
		name => "source"
	);
	$table->appendChild( $repo->render_row(
			$self->html_phrase( "source" ),
			$select
		) );

	foreach my $source (@$sources)
	{
		$select->appendChild( $xml->create_element( "option",
			value => $source->{base_url}
		) )->appendChild( $xml->create_text_node( $source->{name} ) );
	}

	$table->appendChild( $repo->render_row(
			$repo->html_phrase( "user_fieldname_username" ),
			$xhtml->input_field(
				username => scalar($repo->param( "username" )),
				type => "text"
			)
		) );
	$table->appendChild( $repo->render_row(
			$repo->html_phrase( "user_fieldname_password" ),
			$xhtml->input_field(
				password => undef,
				type => "password"
			)
		) );

	$form->appendChild( $repo->render_action_buttons(
		publish => $self->phrase( "action_publish" ),
		cancel => $self->phrase( "action_cancel" ),
		_order => [qw( publish cancel )],
		) );

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

