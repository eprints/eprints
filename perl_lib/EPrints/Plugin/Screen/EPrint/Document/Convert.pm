=head1 NAME

EPrints::Plugin::Screen::EPrint::Document::Convert

=cut

package EPrints::Plugin::Screen::EPrint::Document::Convert;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint::Document' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{icon} = "action_convert.png";

	$self->{appears} = [
		{
			place => "document_item_actions",
			position => 500,
		},
	];
	
	$self->{actions} = [qw/ convert cancel /];

	$self->{ajax} = "interactive";

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	my $doc = $self->{processor}->{document};
	return 0 if !$doc;

	return 0 if !$self->SUPER::can_be_viewed;

	my %available = $self->available( $doc );

	return scalar(keys %available) > 0;
}

sub allow_convert { shift->can_be_viewed( @_ ) }
sub allow_cancel { 1 }

sub render
{
	my( $self ) = @_;

	my $doc = $self->{processor}->{document};

	my $session = $self->{session};

	my %available = $self->available( $doc );

	my $frag = $self->{session}->make_doc_fragment;

	my $div = $self->{session}->make_element( "div", class=>"ep_block" );
	$frag->appendChild( $div );

	$div->appendChild( $self->render_document( $doc ) );

	$div = $self->{session}->make_element( "div", class=>"ep_block" );
	$frag->appendChild( $div );

	$div->appendChild( $self->html_phrase( "help" ) );
	
	$div = $self->{session}->make_element( "div", class=>"ep_block" );
	$frag->appendChild( $div );

	my %buttons = (
		cancel => $self->{session}->phrase(
				"lib/submissionform:action_cancel" ),
		convert => $self->phrase( "action_convert" ),
		_order => [ "convert", "cancel" ]
	);

	my $form= $self->render_form;
	my $select_button = $session->make_element( "select",
			name => "format",
			id => "format",
		);
	$form->appendChild( $select_button );
	foreach my $type (sort keys %available)
	{
		my $plugin_id = $available{$type}->{ "plugin" }->get_id();
		my $phrase_id = $available{$type}->{ "phraseid" };
		my $option = $session->make_element( "option", value => $type );
		$option->appendChild( $session->html_phrase( $phrase_id ));
		$select_button->appendChild( $option );
	}
	$form->appendChild( 
		$self->{session}->render_action_buttons( 
			%buttons ) );
	$div->appendChild( $form );

	return( $frag );
}	

sub action_convert
{
	my( $self ) = @_;

	my $session = $self->{session};

	$self->{processor}->{redirect} = $self->{processor}->{return_to}
		if !$self->wishes_to_export;

	my $eprint = $self->{processor}->{eprint};
	my $doc = $self->{processor}->{document};

	return if !$doc;

	my $type = $self->{session}->param( "format" );
	return if !$type;

	my %available = $self->available( $doc );

	my $info = $available{$type};
	return if !$info;

	my $plugin = $info->{plugin};

	my $new_doc = $plugin->convert( $eprint, $doc, $type );
	if( !$new_doc )
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "conversion_failed" ) );
		return;
	}
	$new_doc->remove_relation( undef, "isVolatileVersionOf" );
	$new_doc->commit();
	$new_doc->queue_files_modified();

	push @{$self->{processor}->{docids}}, $new_doc->id;

	$self->{processor}->{redirect} .= "&docid=".$new_doc->id
		if $self->{processor}->{redirect};
}

sub available
{
	my( $self, $doc ) = @_;

	my $convert = $self->{session}->plugin( "Convert" );
	my %available = $convert->can_convert( $doc );

	my $field = $doc->dataset->get_field( 'format' );
	my %document_formats = map { ($_ => 1) } $field->tags( $self->{session} );

	foreach my $format (keys %available)
	{
		delete $available{$format} if !$document_formats{$format};
	}

	return %available;
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

