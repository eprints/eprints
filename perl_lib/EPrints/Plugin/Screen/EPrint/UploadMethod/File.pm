=head1 NAME

EPrints::Plugin::Screen::EPrint::UploadMethod::File

=cut

package EPrints::Plugin::Screen::EPrint::UploadMethod::File;

use EPrints::Plugin::Screen::EPrint::UploadMethod;

@ISA = qw( EPrints::Plugin::Screen::EPrint::UploadMethod );

use strict;

sub new
{
	my( $self, %params ) = @_;

	return $self->SUPER::new(
		appears => [
			{ place => "upload_methods", position => 200 },
		],
		actions => [qw( add_format )],
		%params );
}

sub redirect_to_me_url { }

sub allow_add_format { shift->can_be_viewed }

sub wishes_to_export
{
	my( $self ) = @_;

	return $self->{session}->get_request->unparsed_uri =~ /\bprogress_id=([a-fA-F0-9]{32})\b/;
}

sub export_mimetype { "text/html" }

sub export
{
	my( $self ) = @_;

	$self->{session}->get_request->unparsed_uri =~ /\bprogress_id=([a-fA-F0-9]{32})\b/;
	my $doc = $self->{processor}->{notes}->{upload_plugin}->{document};
	my $docid = defined $doc ? $doc->id : 'null';

	print <<EOH;
<html>
<body>
<script type="text/javascript">
window.top.window.UploadMethod_file_stop( '$1', $docid );
</script>
</body>
</html>
EOH
}

sub action_add_format
{
	my( $self ) = @_;
	
	my $session = $self->{session};
	my $processor = $self->{processor};
	my $eprint = $processor->{eprint};

	return if !$self->SUPER::action_add_format();

	my $epdata = $processor->{notes}->{epdata};

	my $filename = $epdata->{main};
	return if !defined $filename;

	my $list;
	my $doc = $eprint->create_subdataobj( "documents", $epdata );
	if( defined $doc )
	{
		$list = EPrints::List->new(
			session => $session,
			dataset => $doc->dataset,
			ids => [$doc->id]
		);
		$processor->{notes}->{upload_plugin}->{document} = $doc;
	}

	if( !defined $list || $list->count == 0 )
	{
		$processor->add_message( "error", $session->html_phrase( "Plugin/InputForm/Component/Upload:create_failed" ) );
		return;
	}

	for(@{$list->ids})
	{
		$processor->{notes}->{upload_plugin}->{to_unroll}->{$_} = 1;
	}
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $xml = $session->xml;
	my $ffname = join('_', $self->{prefix}, "file");

	my $f = $xml->create_document_fragment;

	my $container = $xml->create_element( "div",
		class => "UploadMethod_file_container"
	);
	$f->appendChild( $container );

	# upload help
	$container->appendChild( $session->html_phrase( "Plugin/InputForm/Component/Upload:new_document" ) );

	# file selection button
	my $file_button = $xml->create_element( "input",
		name => $ffname,
		id => $ffname,
		type => "file",
		onchange => "UploadMethod_file_change(this,'$self->{parent}->{prefix}','$self->{prefix}')",
		);
	$container->appendChild( $file_button );

	# upload button
	my $add_format_button = $session->render_button(
		value => $self->{session}->phrase( "Plugin/InputForm/Component/Upload:add_format" ), 
		class => "ep_form_internal_button",
		name => "_internal_".$self->{prefix}."_add_format",
		id => "_internal_".$self->{prefix}."_add_format",
		);
	$container->appendChild( $session->make_text( " " ) );
	$container->appendChild( $add_format_button );

	return $f;
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

