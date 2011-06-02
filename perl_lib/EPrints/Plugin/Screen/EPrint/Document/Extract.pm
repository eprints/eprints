=head1 NAME

EPrints::Plugin::Screen::EPrint::Document::Extract

=cut

package EPrints::Plugin::Screen::EPrint::Document::Extract;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint::Document' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{icon} = "action_extract.png";

	$self->{appears} = [
		{
			place => "document_item_actions",
			position => 300,
		},
	];
	
	$self->{actions} = [qw/ merge replace cancel /];

# Extract updates metadata which is troublesome in AJAX
#	$self->{ajax} = "interactive";

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	my $doc = $self->{processor}->{document};
	return 0 if !$doc;

	return 0 if !$self->SUPER::can_be_viewed;

	return $self->available( $doc ) > 0;
}

sub allow_merge { shift->can_be_viewed( @_ ) }
sub allow_replace { shift->can_be_viewed( @_ ) }
sub allow_cancel { 1 }

sub render
{
	my( $self ) = @_;

	my $doc = $self->{processor}->{document};

	my $session = $self->{session};

	my @available = $self->available( $doc );
	my %actions;
	foreach my $plugin (@available)
	{
		foreach my $action (@{$plugin->param( "actions" )})
		{
			push @{$actions{$action}}, $plugin;
		}
	}

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
		merge => $self->phrase( "action_merge" ),
		replace => $self->phrase( "action_replace" ),
		_order => [ "merge", "replace", "cancel" ]
	);

	my $form= $self->render_form;
	my $ul = $self->{session}->make_element( "ul",
		style => "list-style-type: none"
	);
	$form->appendChild( $ul );
	foreach my $action (sort keys %actions)
	{
		my $li = $self->{session}->make_element( "li" );
		$ul->appendChild( $li );
		my $action_id = "action_$action";
		my $checkbox = $self->{session}->make_element( "input",
			type => "checkbox",
			name => $action_id,
			id => $action_id,
			value => "yes",
		);
		$li->appendChild( $checkbox );
		my $label = $self->{session}->make_element( "label",
			for => $action_id,
		);
		$li->appendChild( $label );
		$label->appendChild( $actions{$action}->[0]->html_phrase( $action_id ) );
	}
	$form->appendChild( 
		$self->{session}->render_action_buttons( 
			%buttons ) );
	$div->appendChild( $form );

	return( $frag );
}	

sub action_merge
{
	my( $self ) = @_;

	$self->_action( 0 );
}

sub action_replace
{
	my( $self ) = @_;

	$self->_action( 1 );
}

sub _action
{
	my( $self, $replace ) = @_;

	my $session = $self->{session};

	$self->action_cancel; # return_to the workflow

	my $eprint = $self->{processor}->{eprint};
	my $doc = $self->{processor}->{document};
	return if !$doc;

	my $file = $doc->stored_file( $doc->value( "main" ) );
	return if !$file;

	my $fh = $file->get_local_copy;
	return if !$fh;

	my $epdata;
	my @available = $self->available( $doc,
		Handler => EPrints::CLIProcessor->new(
			message => sub { $self->{processor}->add_message( @_ ) },
			epdata_to_dataobj => sub { $epdata = $_[0] },
		),
		parse_only => 1
	);

	foreach my $plugin (@available)
	{
		my @actions;
		foreach my $action (@{$plugin->param( "actions" )})
		{
			push @actions, $action if $session->param( "action_$action" );
		}
		next if !@actions;

		$plugin->input_fh(
			fh => $fh,
			dataset => $eprint->dataset,
			actions => \@actions,
			filename => "MAINFILE",
		);
		seek($fh,0,0);
		next if !defined $epdata;

		$self->update_eprint( $eprint, $doc, $epdata, $replace );

		undef $epdata;
	}

	$eprint->commit;

	$self->{processor}->add_message( "message", $self->html_phrase( "done" ) );
}

sub available
{
	my( $self, $doc, %params ) = @_;

	my @available;
	
	foreach my $plugin ($self->{session}->get_plugins( \%params,
			type => "Import",
			can_accept => $doc->value( "format" ),
			can_produce => "dataobj/eprint",
			can_action => "*",
		))
	{
		push(@available, $plugin);
	}

	return @available;
}

sub update_eprint
{
	my( $self, $eprint, $doc, $epdata, $replace ) = @_;

	my @documents = @{delete($epdata->{documents}) || []};

	foreach my $fieldname (keys %$epdata)
	{
		next if !$eprint->dataset->has_field( $fieldname );
		next if !$replace && $eprint->is_set( $fieldname );
		my $field = $eprint->dataset->field( $fieldname );
		next if !$field->property( "import" );
		if( $field->isa( "EPrints::MetaField::Subobject" ) )
		{
		}
		else
		{
			$field->set_value( $eprint, $epdata->{$fieldname} );
		}
	}

	foreach my $docdata (@documents)
	{
		next if $docdata->{main} eq "MAINFILE";
		$docdata->{relation} ||= [];
		push @{$docdata->{relation}}, {
			type => EPrints::Utils::make_relation( "isPartOf" ),
			uri => $doc->internal_uri
		};
		my $new_doc = $eprint->create_subdataobj( "documents", $docdata );
		next if !$new_doc;
		push @{$self->{processor}->{docids}}, $new_doc->id;
	}
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

