
package EPrints::Plugin::InputForm::UploadMethod;

use EPrints;
use EPrints::Plugin;

@ISA = ( "EPrints::Plugin" );

use strict;

sub render_tab_title
{
	my( $self ) = @_;

	return $self->{session}->make_text( "You need to over-ride the render_tab_title method on your UpdateMethod" );

}

sub update_from_form
{
	my( $self, $processor ) = @_;

#	$processor->{notes}->{upload_plugin}->{to_unroll}->{$document->get_id} = 1;
}

sub render_add_document
{
	my( $self ) = @_;

	my $f = $self->{session}->make_doc_fragment;

	$f->appendChild( $self->{session}->make_text( "You need to over-ride the render_add_document method on your UpdateMethod" ) );
}


