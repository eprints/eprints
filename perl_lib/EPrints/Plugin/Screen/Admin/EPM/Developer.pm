=head1 NAME

EPrints::Plugin::Screen::Admin::EPM::Developer

=cut

package EPrints::Plugin::Screen::Admin::EPM::Developer;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ edit download publish create /];
		
	$self->{appears} = [
		{ 
			place => "admin_epm_tabs", 
			position => 1000, 
		},
	];

	return $self;
}

sub can_be_viewed { shift->EPrints::Plugin::Screen::Admin::EPM::can_be_viewed( @_ ) }
sub allow_create { shift->can_be_viewed( @_ ) }
sub allow_edit { shift->can_be_viewed( @_ ) }
sub allow_download { shift->can_be_viewed( @_ ) }
sub allow_publish { shift->can_be_viewed( @_ ) }

sub properties_from
{
	shift->EPrints::Plugin::Screen::Admin::EPM::properties_from();
}

sub action_create
{
	my( $self ) = @_;

	my $epmid = $self->{repository}->param( "epmid" );
	return if !EPrints::Utils::is_set( $epmid );

	if( $epmid =~ /[^A-Za-z0-9_]/ )
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "error:bad_epmid", epmid => $self->{repository}->xml->create_text_node( $epmid ) ) );
		return;
	}

	my $epm = $self->{repository}->dataset( "epm" )->make_dataobj( {
		epmid => $epmid,
		version => '1.0.0',
	});
	$epm->commit;
	
	$self->{processor}->{dataobj} = $epm;

	$self->{processor}->{screenid} = "Admin::EPM::Edit";
}

sub action_edit
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "Admin::EPM::Edit";
}

sub action_download
{
	my( $self ) = @_;

	my $epm = $self->{processor}->{dataobj};
	return if !defined $epm;

	my $r = $self->{repository}->get_request;

	$r->headers_out->{'Content-Disposition'} = 'attachment; filename="'.$epm->package_filename.'"';
	$r->headers_out->{'Content-Type'} = "application/vnd.eprints.epm+xml;charset=utf-8";
	
	$epm->rebuild;

	binmode(STDOUT, ":utf8");
	print $epm->serialise( 1 );

	exit(0);
}

sub action_publish
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "Admin::EPM::Publish";
}

sub render
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $frag = $xml->create_document_fragment;

	my $dataset = $repo->dataset( "epm" );
	
	$dataset->dataobj_class->map( $repo, sub {
		my( undef, undef, $epm ) = @_;

		my $link = $repo->current_url( host => 1 );
		$link->query_form(
			$self->hidden_bits,
			export => 1,
			dataobj => $epm->id,
		);

		my $actions = $xml->create_document_fragment;
		my $form = $self->render_form;
		$actions->appendChild( $form );
		$form->appendChild( $xhtml->hidden_field(
			dataobj => $epm->id,
		) );
		$form->appendChild( $repo->render_action_buttons(
			edit => $self->phrase( "action_edit" ),
			download => $self->phrase( "action_download" ),
			publish => $self->phrase( "action_publish" ),
			_order => [qw( edit download publish )],
		) );

		$frag->appendChild( $epm->render_citation( "developer",
			pindata => { inserts => {
				actions => $actions,
			} },
		) );
	});

	my $form = $self->render_form;
	my $field = $dataset->key_field;
	$form->appendChild( $field->render_input_field(
		$repo
	) );
	$form->appendChild( $repo->render_action_buttons(
		create => $self->phrase( "action_create" ),
	) );
	$frag->appendChild( $self->html_phrase( "create_form",
		form => $form,
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

