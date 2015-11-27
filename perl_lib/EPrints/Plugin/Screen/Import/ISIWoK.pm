=head1 NAME

EPrints::Plugin::Screen::Import::ISIWoK

=cut

package EPrints::Plugin::Screen::Import::ISIWoK;

@ISA = ( 'EPrints::Plugin::Screen::Import' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ test_data import_data import_single /];

	return $self;
}

sub wishes_to_export { shift->{repository}->param( "ajax" ); }
sub export_mimetype { "text/html;charset=utf-8" };
sub export
{
	my( $self ) = @_;

	my $item = $self->{processor}->{items}->[0];
	$self->{repository}->not_found, return if !defined $item;

	my $link = $self->{repository}->xml->create_data_element( "a",
		$item->id,
		href => $item->uri,
	);

	binmode(STDOUT, ":utf8");
	print $self->{repository}->xml->to_string( $link );
}

sub properties_from
{
	my( $self ) = @_;

	$self->SUPER::properties_from;

	$self->{processor}->{offset} = $self->{repository}->param( "results_offset" );
	$self->{processor}->{offset} ||= 0;

	$self->{processor}->{data} = $self->{repository}->param( "data" );

	$self->{processor}->{ut} = $self->{repository}->param( "ut" );

	$self->{processor}->{items} = [];
}

sub allow_import_single { shift->can_be_viewed }

sub arguments
{
	my( $self ) = @_;

	return(
		offset => $self->{processor}->{offset},
	);
}

sub action_test_data
{
	my( $self ) = @_;

	my $tmpfile = File::Temp->new;
	syswrite($tmpfile, scalar($self->{repository}->param( "data" )));
	sysseek($tmpfile, 0, 0);

	my $list = $self->run_import( 1, 1, $tmpfile ); # dry run without messages
	$self->{processor}->{results} = $list;
}

sub action_import_data
{
	my( $self ) = @_;

	local $self->{i} = 0;

	$self->SUPER::action_import_data;
}

sub epdata_to_dataobj
{
	my( $self, $epdata, %opts ) = @_;

	my $dataobj = $self->SUPER::epdata_to_dataobj( $epdata, %opts );

	push @{$self->{processor}->{items}},
		($dataobj || $opts{dataset}->make_dataobj( $epdata ));

	return $dataobj;
}

sub action_import_single
{
	my( $self ) = @_;

	my $repo = $self->{repository};

	my $eprint;

	my $plugin = $repo->plugin("Import::ISIWoK");
	$plugin->set_handler(EPrints::CLIProcessor->new(
		message => sub { $self->{processor}->add_message( @_ ) },
		epdata_to_dataobj => sub {
			$eprint = $self->SUPER::epdata_to_dataobj( @_ );
		},
	) );

	{
		my $q = "UT = ($self->{processor}->{ut})";
		open(my $fh, "<", \$q);
		$plugin->input_fh(
				dataset => $repo->dataset( "inbox" ),
				fh => $fh,
			);
	}

	if( !defined $eprint )
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "error:not_found",
			ut => $self->{repository}->xml->create_text_node( $self->{processor}->{ut} )
			) );
		return;
	}

	my $fh = $self->{repository}->get_query->upload( "file" );
	if( defined $fh )
	{
		my $filename = $self->{repository}->param( "file" );
		$filename ||= "main.bin";
		my $filepath = $self->{repository}->query->tmpFileName( $fh );

		$repo->run_trigger( EPrints::Const::EP_TRIGGER_MEDIA_INFO,
			filename => $filename,
			filepath => $filepath,
			epdata => my $media_info = {},
		);

		$eprint->create_subdataobj( 'documents', {
			%$media_info,
			main => $filename,
			files => [{
				_content => $fh,
				filename => $filename,
				filesize => -s $fh,
				mime_type => $media_info->{mime_type},
			}],
		});
	}

	$self->{processor}->add_message( "message", $repo->html_phrase( "Plugin/Screen/Import:import_completed",
		count => $repo->xml->create_text_node( 1 )
		) );

	if( !$self->wishes_to_export )
	{
		$self->{processor}->{items} = [];

		# re-run the search query
		$self->action_test_data;
	}
}

sub render_links
{
	my( $self ) = @_;

	my $frag = $self->SUPER::render_links;

	$frag->appendChild( $self->{repository}->make_javascript( undef,
		src => $self->{repository}->current_url( path => "static", "javascript/screen_import_isiwok.js" )
	) );

	return $frag;
}

sub render
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $items = $self->{processor}->{items};

	my $frag = $xml->create_document_fragment;

	$frag->appendChild( $self->html_phrase( "help" ) )
		if !defined $items;

	my $form = $frag->appendChild( $self->render_form );
	$form->appendChild( EPrints::MetaField->new(
			name => "data",
			type => "longtext",
			repository => $repo,
		)->render_input_field(
			$repo,
			$self->{processor}->{data},
		) );
	$form->appendChild( $xhtml->input_field(
		_action_test_data => $repo->phrase( "lib/searchexpression:action_search" ),
		type => "submit",
		class => "ep_form_action_button",
	) );

	if( defined $items )
	{
		$frag->appendChild( $self->render_results( $items ) );
	}

	return $frag;
}

sub render_results
{
	my( $self, $items ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $frag = $xml->create_document_fragment;

	$frag->appendChild( $xml->create_data_element( "h2",
		$self->html_phrase( "results" )
	) );

	my $offset = $self->{processor}->{offset};

	my $total = $self->{processor}->{plugin}->{total};
	$total = 1000 if $total > 1000;

	my $i = 0;
	my $list = EPrints::Plugin::Screen::Import::ISIWoK::List->new(
		session => $repo,
		dataset => $repo->dataset( "inbox" ),
		ids => [0 .. ($total - 1)],
		items => {
				map { ($offset + $i++) => $_ } @$items
			}
		);

	$frag->appendChild( EPrints::Paginate->paginate_list(
		$repo, "results", $list,
		container => $xml->create_element( "table" ),
		params => {
			$self->hidden_bits,
			data => $self->{processor}->{data},
			_action_test_data => 1,
		},
		render_result => sub {
			my( undef, $eprint, undef, $n ) = @_;
			my @dupes = $self->find_duplicate( $eprint );
			my $row = $eprint->render_citation( "result",
				n => [$n, "INTEGER"],
			);
			my( $tr ) = $row->getElementsByTagName( "tr" );
			my $td = $tr->appendChild( $xml->create_element( "td" ) );
			my $form = $self->render_form;
			$form->setAttribute( class => "import_single" );
			$td->appendChild( $form );
			$form->appendChild(
				$xhtml->hidden_field( data => $self->{processor}->{data} )
			);
			$form->appendChild(
				$xhtml->hidden_field( results_offset => $self->{processor}->{offset} )
			);
			$form->appendChild(
				$xhtml->hidden_field( ut => $eprint->value( "source" ) )
			);
			$form->appendChild( $xhtml->input_field(
				file => undef,
				type => "file",
			) );
			$form->appendChild( $repo->render_action_buttons(
				import_single => $self->phrase( "action_import_single" ),
			) );
			if( @dupes )
			{
				$td->appendChild( $self->html_phrase( "duplicates" ) );
			}
			foreach my $dupe (@dupes)
			{
				$td->appendChild( $xml->create_data_element( "a",
					$dupe->id,
					href => $dupe->uri,
				) );
				$td->appendChild( $xml->create_text_node( ", " ) )
					if $dupe ne $dupes[$#dupes];
			}
			return $row;
		},
	) );

	return $frag;
}

sub find_duplicate
{
	my( $self, $eprint ) = @_;

	my @terms = split /\W+/, $eprint->value( "title" );
	@terms = sort { length($b) <=> length($a) } @terms;
	@terms = @terms[0..4] if @terms > 5;

	my @dupes;

	$self->{repository}->dataset( "eprint" )->search(
		filters => [
			{ meta_fields => [qw( source )], value => $eprint->value("source"), match => "EX", },
		],
		limit => 5,
	)->map(sub {
		(undef, undef, my $dupe) = @_;

		push @dupes, $dupe;
	});

	return @dupes;
}

package EPrints::Plugin::Screen::Import::ISIWoK::List;

our @ISA = qw( EPrints::List );

sub _get_records
{
	my( $self, $offset, $count, $justids ) = @_;

	$offset = 0 if !defined $offset;
	$count = $self->count - $offset if !defined $count;
	$count = @{$self->{ids}} if $offset + $count > @{$self->{ids}};

	my $ids = [ @{$self->{ids}}[$offset .. ($offset + $count - 1)] ];

	return $justids ?
		$ids :
		(grep { defined $_ } map { $self->{items}->{$_} } @$ids);
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

