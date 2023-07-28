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
		actions => [qw( add_format create_file finish_file )],
		%params );
}

sub redirect_to_me_url { }

sub allow_add_format { shift->can_be_viewed }
sub allow_create_file { shift->can_be_viewed }
sub allow_finish_file { shift->can_be_viewed }

sub wishes_to_export
{
	my( $self ) = @_;

	return $self->{session}->get_request->unparsed_uri =~ /\bajax=\b/;
}

sub export_mimetype 
{
	shift->{session}->get_request->unparsed_uri =~ /\bajax=([a-z_]+)\b/;
	return "text/html" if $1 eq "add_format";
	return "application/json";
}

sub export
{
	my( $self ) = @_;

	my $repo = $self->{session};

	my $doc = $self->{processor}->{notes}->{upload_plugin}->{document};
	my $file = $self->{processor}->{notes}->{upload_plugin}->{file};

	my %q = URI::http->new( $repo->get_request->unparsed_uri )->query_form;

	my $progressid = $q{progressid};
	my $ajax = $q{ajax};

	if( $ajax eq "add_format" )
	{
		my $docid = defined $doc ? $doc->id : 'null';

		print <<EOH;
<html>
<body>
<script type="text/javascript">
window.top.window.UploadMethod_file_stop( '$progressid', $docid );
</script>
</body>
</html>
EOH
		return;
	}

	my %data;

	if( defined $doc )
	{
		$data{docid} = $doc->id;
	}
	if( defined $file )
	{
		$data{fileid} = $file->id;
	}
	$data{phrases}{abort} = $repo->phrase( "lib/submissionform:action_cancel" );

	my $plugin = $self->{session}->plugin( "Export::JSON" );
	print $plugin->output_dataobj( \%data );
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

	# remove leading/trailing whitespace from filename used on filesystem
	my $f = 0;
	while ( defined $epdata->{files}[$f] )
	{
		my $tmp_filename = $epdata->{files}[$f]->{filename};
		$tmp_filename =~ s/^\s+|\s+$//g;
		$epdata->{files}[$f++]->{filename} = $tmp_filename;
	}

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

sub action_create_file
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $processor = $self->{processor};
	my $eprint = $processor->{eprint};

	my $filename = $session->param( "filename" );
	$filename = "main.bin" if !EPrints::Utils::is_set( $filename );

	my $mime_type = $session->param( "mime_type" );
	$mime_type = "application/octet-stream" if !EPrints::Utils::is_set( $mime_type );

	my $doc = $eprint->create_subdataobj( "documents", {
			main => $filename,
			mime_type => $mime_type,
			format => "other",
		});

	my $file = $doc->create_subdataobj( "files", {
			filename => $filename,
			filesize => 0,
			mime_type => $mime_type,
		});

	$processor->{notes}->{upload_plugin}->{document} = $doc;
	$processor->{notes}->{upload_plugin}->{file} = $file;
}

sub action_finish_file
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $processor = $self->{processor};
	my $eprint = $processor->{eprint};

	my $file = $session->dataset( "file" )->dataobj( $session->param( "fileid" ) );
	return if !defined $file;

	my $doc = $file->parent;
	return if !defined $doc || !$doc->isa( "EPrints::DataObj::Document" );

	return if $doc->value( "eprintid" ) ne $eprint->id;

	my $epdata = {};

	my $tmpfile = $file->get_local_copy;

	$session->run_trigger( EPrints::Const::EP_TRIGGER_MEDIA_INFO,
			filepath => "$tmpfile",
			filename => $file->value( "filename" ),
			epdata => $epdata,
		);

	$file->set_value( "mime_type", $epdata->{mime_type} );
	foreach my $fieldid (keys %$epdata)
	{
		next if !$doc->{dataset}->has_field( $fieldid );
		$doc->set_value( $fieldid, $epdata->{$fieldid} );
	}

	if( !$file->is_set( "hash" ) )
	{
		$file->update_md5();
	}

	$doc->queue_files_modified;

	$file->commit;
	$doc->commit;
}

sub render
{
	my( $self, $component ) = @_;

	my $session = $self->{session};
	my $xml = $session->xml;
	my $ffname = join('_', $self->{prefix}, "file");

	my $f = $xml->create_document_fragment;

	my $container = $xml->create_element( "div",
		class => "UploadMethod_file_container",
		id => join('_', $self->{prefix}, "dropbox"),
	);
	$f->appendChild( $container );

	$container->appendChild( $xml->create_data_element( "div",
			$session->html_phrase( "Plugin/InputForm/Component/Upload:drag_and_drop" ),
			style => "display: none;",
			id => join('_', $self->{prefix}, "dropbox_help"),
		) );

	# file selection button
	$container->appendChild( $xml->create_element( "input",
		name => $ffname,
		id => $ffname,
		type => "file",
		onchange => "UploadMethod_file_change(this,'$self->{parent}->{prefix}','$self->{prefix}')",
		) );

	# upload button
	my $add_format_button = $session->render_button(
		value => $self->{session}->phrase( "Plugin/InputForm/Component/Upload:add_format" ), 
		class => "ep_form_internal_button ep_no_js",
		name => "_internal_".$self->{prefix}."_add_format",
		id => "_internal_".$self->{prefix}."_add_format",
		);
	$container->appendChild( $session->make_text( " " ) );
	$container->appendChild( $add_format_button );

	$container->appendChild( $xml->create_element( "table",
			id => join('_', $self->{prefix}, "progress_table"),
			class => "UploadMethod_file_progress_table",
		) );

	$container->appendChild( $session->make_javascript( <<EOJ ) );
var div = \$('$self->{prefix}_dropbox');
var body = document.getElementsByTagName ('body').item (0);
var controller = new Screen_EPrint_UploadMethod_File ('$self->{prefix}', '$component');
Event.observe (div, 'drop', function(evt) {
		controller.dragFinish (evt);
		controller.drop (evt);
	});
Event.observe (body, 'ep:dragcommence', function(evt) {
		controller.dragCommence (evt);
	});
Event.observe (body, 'ep:dragfinish', function(evt) {
		controller.dragFinish (evt);
	});
EOJ

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

