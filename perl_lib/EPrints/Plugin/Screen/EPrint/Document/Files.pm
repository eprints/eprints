=head1 NAME

EPrints::Plugin::Screen::EPrint::Document::Files

=cut

package EPrints::Plugin::Screen::EPrint::Document::Files;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint::Document' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{icon} = "action_files.png";

	$self->{appears} = [
		{
			place => "document_item_actions",
			position => 900,
		},
	];
	
	$self->{actions} = [qw/ cancel update add_file /];

	$self->{ajax} = "interactive";

	return $self;
}

sub allow_cancel { 1 }
sub allow_add_file { shift->can_be_viewed( @_ ) }
sub allow_update { shift->can_be_viewed( @_ ) }

sub can_be_viewed
{
	my( $self ) = @_;

	my $doc = $self->{processor}->{document};
	return 0 if !$doc;

	return 0 if !$self->SUPER::can_be_viewed;

	return 1;
}

sub json
{
	my( $self ) = @_;

	my $json = $self->SUPER::json;
	return $json if !$self->{processor}->{refresh};

	for(@{$json->{documents}})
	{
		$_->{refresh} = 1, last
			if $_->{id} == $self->{processor}->{document}->id;
	}

	return $json;
}

sub render
{
	my( $self ) = @_;

	my $doc = $self->{processor}->{document};

	my $frag = $self->{session}->make_doc_fragment;

	my $div = $self->{session}->make_element( "div", class=>"ep_block" );
	$frag->appendChild( $div );

	$div->appendChild( $self->render_document( $doc ) );

	$div = $self->{session}->make_element( "div", class=>"ep_block" );
	$frag->appendChild( $div );

	$div->appendChild( $self->html_phrase( "help" ) );
	
	my %buttons = (
		cancel => $self->{session}->phrase(
				"lib/submissionform:action_cancel" ),
		update => $self->phrase( "update" ),
		_order => [ qw( update cancel ) ]
	);

	my $form= $self->render_form;
	$form->appendChild( $self->_render_filelist( $doc ) );
	$form->appendChild( 
		$self->{session}->render_action_buttons( 
			%buttons ) );
	$div->appendChild( $form );

	# note: the first form in the return will get AJAXed, which we can't do for
	# file uploads
	my $block = $self->{session}->make_element( "div", class=>"ep_block" );
	$block->appendChild( $self->_render_add_file( $doc, $doc->value( 'files' ) ) );
	$div->appendChild( $block );

	return( $frag );
}	

sub action_update
{
	my( $self ) = @_;

	$self->{processor}->{redirect} = $self->{processor}->{return_to}
		if !$self->wishes_to_export;

	my $doc = $self->{processor}->{document};
	my $files = $doc->value( "files" );

	my $repo = $self->{session};

	my $main = $repo->param( "main" );
	foreach my $file (@$files)
	{
		if( defined($main) && $main eq $file->value( "filename" ) )
		{
			$doc->set_value( "main", $main );
			$doc->commit;
			$self->{processor}->{refresh} = 1;
		}
		elsif( $repo->param( "delete_".$file->id ) )
		{
			$file->remove();
			$self->{processor}->{refresh} = 1;
		}
	}
}

sub action_add_file
{
	my( $self ) = @_;

	$self->{processor}->{redirect} = $self->{processor}->{return_to};

	my $ok = EPrints::Apache::AnApache::upload_doc_file(
		$self->{session},
		$self->{processor}->{document},
		"filename" );
	if( $ok )
	{
		$self->{processor}->{refresh} = 1;
	}
	else
	{
		$self->{processor}->add_message( "error", $self->{session}->html_phrase( "Plugin/InputForm/Component/Documents:upload_failed" ) );
	}
}

sub _render_add_file
{
	my( $self, $document, $files ) = @_;

	my $session = $self->{session};
	
	# Create a document-specific prefix
	my $docid = $document->get_id;
	my $doc_prefix = $self->{prefix}."_doc".$docid;

	my $hide = @$files == 1;

	my $f = $session->make_doc_fragment;	
	if( $hide )
	{
		my $hide_add_files = $session->make_element( "div", id=>$doc_prefix."_af1" );
		my $really_add = EPrints::Utils::js_string( $session->phrase( "Plugin/InputForm/Component/Documents:really_add" ) );
		my $show = $self->{session}->make_element( "a",
			class=>"ep_only_js",
			style=>"display: block; height: 2em;",
			href=>"#",
			onclick => "EPJS_blur(event); if(!confirm(".$really_add.")) { return false; } EPJS_toggle('${doc_prefix}_af1',true);EPJS_toggle('${doc_prefix}_af2',false);return false",
		);
		$hide_add_files->appendChild( $session->html_phrase( 
			"Plugin/InputForm/Component/Documents:add_files",
			link=>$show ));
		$f->appendChild( $hide_add_files );
	}

	my %l = ( id=>$doc_prefix."_af2", class=>"ep_upload_add_file_toolbar" );
	$l{class} .= " ep_no_js" if( $hide );
	my $form = $self->render_form();
	my $toolbar = $session->make_element( "div", %l );
	$form->appendChild( $toolbar );
	my $file_button = $session->make_element( "input",
		name => "filename",
		id => "filename",
		type => "file",
		);
	my $upload_button = $session->render_button(
		name => "_action_add_file",
		class => "ep_form_internal_button",
		value => $session->phrase( "Plugin/InputForm/Component/Documents:add_file" ),
		);
	$toolbar->appendChild( $file_button );
	$toolbar->appendChild( $session->make_text( " " ) );
	$toolbar->appendChild( $upload_button );
	$f->appendChild( $form );

	return $f; 
}

sub _render_filelist
{
	my( $self, $doc ) = @_;

	my $session = $self->{session};
	
	my $files = $doc->value( "files" );
	my $doc_prefix = $self->{prefix}."_doc".$doc->id;

	my $main_file = $doc->get_main;
	
	my $div = $session->make_element( "div", class=>"ep_upload_files" );

	my $table = $session->make_element( "table", class => "ep_upload_file_table" );
	$div->appendChild( $table );

	my $tr = $session->make_element( "tr", class => "ep_row" );
	$table->appendChild( $tr );
	my @fields;
	for(qw( filename filesize mime_type hash_type hash ))
	{
		push @fields, $session->dataset( "file" )->field( $_ );
	}
	push @fields, $session->dataset( "document" )->field( "main" );
	foreach my $field (@fields)
	{
		my $td = $session->make_element( "th" );
		$tr->appendChild( $td );
		$td->appendChild( $field->render_name( $session ) );
	}
	do { # actions
		my $td = $session->make_element( "th" );
		$tr->appendChild( $td );
		$td->appendChild( $session->html_phrase( "Plugin/InputForm/Component/Documents:delete_file" ) );
	};

	foreach my $file (@$files)
	{
		$table->appendChild( $self->_render_file( $doc, $file ) );
	}
	
	return $div;
}

sub _render_file
{
	my( $self, $doc, $file ) = @_;

	my $session = $self->{session};

	my $imagesurl = $session->current_url( path => "static" );

	my $doc_prefix = "doc".$doc->id;
	my $filename = $file->value( "filename" );
	my $is_main = $filename eq $doc->get_main;

	my @values;

	my $link = $session->render_link( $doc->get_url( $filename ), "_blank" );
	$link->appendChild( $session->make_text( $filename ) );
	push @values, $link;
	
	for( qw( filesize mime_type hash_type hash ) )
	{
		push @values, $file->render_value( $_ );
	}
	
	push @values, $session->make_element( "input",
		type => "radio",
		name => "main",
		value => $filename,
		($is_main ? (checked => "checked") : ()) );

	push @values, $session->make_element( "input", 
		type => "checkbox", 
		name => "delete_".$file->id,
		id => "delete_".$file->id,
		);

	return $session->render_row( @values );
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

