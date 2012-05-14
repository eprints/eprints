=head1 NAME

EPrints::Plugin::Screen::EPrint::Document

=cut

package EPrints::Plugin::Screen::EPrint::Document;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub redirect_to_me_url
{
	my( $self ) = @_;
	
	return $self->wishes_to_export ? undef : $self->SUPER::redirect_to_me_url;
}

sub wishes_to_export
{
	my( $self ) = @_;

	return $self->{session}->param( "export" );
}

sub export_mimetype { "application/json" }

sub json
{
	my( $self ) = @_;

	my %json = ( documents => [], messages => [] );

	foreach my $doc ($self->{processor}->{eprint}->get_all_documents)
	{
		push @{$json{documents}}, {
			id => $doc->id,
			placement => $doc->value( "placement" ),
		};
	}

	my $messages = $self->{processor}->render_messages;
	foreach my $content ($messages->childNodes)
	{
		push @{$json{messages}}, $content->toString();
	}
	$self->{repository}->xml->dispose( $messages );

	return \%json;
}

sub export
{
	my( $self ) = @_;

	my $plugin = $self->{session}->plugin( "Export::JSON" );
	print $plugin->output_dataobj( $self->json );
}

sub action_cancel
{
	my( $self ) = @_;

	$self->{processor}->{redirect} = $self->{processor}->{return_to}
		if !$self->wishes_to_export;
}

sub render_document
{
	my( $self, $doc ) = @_;

	my $files = $doc->value( "files" );

	return $self->EPrints::Plugin::InputForm::Component::Documents::_render_doc_icon_info( $doc, $files );
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0 unless $self->could_obtain_eprint_lock;
	return $self->allow( "eprint/edit" );
}

sub render_title
{
	shift->EPrints::Plugin::Screen::render_title( @_ );
}

sub obtain_lock
{
	my( $self ) = @_;

	return $self->could_obtain_eprint_lock;
}

sub properties_from
{
	my( $self ) = @_;

	$self->SUPER::properties_from;

	my $uri = URI->new( $self->{session}->current_url( host => 1 ) );
	$uri->query( $self->{session}->param( "return_to" ) );
	$self->{processor}->{return_to} = $uri;

	my $doc = $self->{session}->dataset( "document" )->dataobj(
			$self->{session}->param( "documentid" )
		);
	if( $doc && $doc->value( "eprintid" ) == $self->{processor}->{eprint}->id )
	{
		$self->{processor}->{document} = $doc;
	}
}

sub hidden_bits
{
	my( $self ) = @_;

	return(
		$self->SUPER::hidden_bits,
		documentid => $self->{processor}->{document}->id,
		return_to => $self->{processor}->{return_to}->query,
	);
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

