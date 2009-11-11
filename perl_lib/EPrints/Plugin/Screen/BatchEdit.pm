package EPrints::Plugin::Screen::BatchEdit;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

our @IGNORE_FIELDS = qw(
	eprintid
	rev_number
	documents
	dir
	datestamp
	lastmod
	status_changed
	succeeds
	commentary
	replacedby
	metadata_visibility
	fileinfo
);

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ edit /];

	# is linked to by the BatchEdit export plugin
	$self->{appears} = [];

	return $self;
}

sub allow_edit
{
	$_[0]->can_be_viewed
}

sub can_edit
{
	$_[0]->can_be_viewed
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "eprint/archive/edit" );
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	my $cacheid = $self->{processor}->{session}->param( "cache" );

	return $self->SUPER::redirect_to_me_url."&cache=$cacheid";
}

sub get_cache
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my $cacheid = $session->param( "cache" );

	my $dataset = $session->get_repository->get_dataset( "cachemap" );
	my $cache = $dataset->get_object( $session, $cacheid );

	return $cache;
}

sub get_searchexp
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my $cacheid = $session->param( "cache" );

	my $cache = $self->get_cache();

	my $searchexp = EPrints::Search->new(
		session => $session,
		dataset => $session->get_repository->get_dataset( "eprint" ),
		keep_cache => 1,
	);

	if( $searchexp )
	{
		$searchexp->from_string_raw( $cache->get_value( "searchexp" ) );
		$searchexp->{"cache_id"} = $cacheid;
	}

	return $searchexp;
}

sub action_edit
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my $searchexp = $self->get_searchexp;
	if( !$searchexp )
	{
		return;
	}

	my $list = $searchexp->perform_search;

	if( $list->count == 0 )
	{
		return;
	}

	my $dataset = $searchexp->get_dataset;

	my %changes = $self->get_changes( $dataset );

	$list->map(sub {
		my( $session, $dataset, $object ) = @_;

		while(my( $fieldname, $opts ) = each %changes)
		{
			my $field = $dataset->get_field( $fieldname );
			my $action = $opts->{"action"};
			my $value = $opts->{"value"};
			my $orig_value = $object->get_value( $fieldname );

			if( $action eq "clear" )
			{
				$object->set_value( $fieldname,
					$field->get_property( "multiple" ) ? [] : undef );
			}
			elsif( $action eq "delete" )
			{
				if( $field->get_property( "multiple" ) )
				{
					my $values = $object->get_value( $fieldname );
					@$values = grep { cmp_deeply($value, $_) != 0 } @$values;
					$object->set_value( $fieldname, $values );
				}
				else
				{
				}
			}
			elsif( $action eq "replace" )
			{
				if( $field->get_property( "multiple" ) )
				{
				}
				else
				{
					$object->set_value( $fieldname, $value );
				}
			}
			elsif( $action eq "insert" )
			{
				$value = [$value, @$orig_value];
				$object->set_value( $fieldname, $value );
			}
			elsif( $action eq "append" )
			{
				$value = [@$orig_value, $value];
				$object->set_value( $fieldname, $value );
			}
		}

		$object->commit;
	});

	if( %changes )
	{
		my $ul = $session->make_element( "ul" );
		while(my( $fieldname, $opts ) = each %changes)
		{
			my $field = $dataset->get_field( $fieldname );
			my $action = $opts->{"action"};
			my $value = $opts->{"value"};
			my $li = $session->make_element( "li" );
			$ul->appendChild( $li );
			$value = defined($value) ?
				$field->render_single_value( $session, $value ) :
				$session->html_phrase( "lib/metafield:unspecified" );
			$li->appendChild( $self->html_phrase( "applied_$action",
				value => $value,
				fieldname => $session->html_phrase( "eprint_fieldname_$fieldname" ),
			) );
		}
		$processor->add_message( "message", $self->html_phrase( "applied",
			changes => $ul,
		) );
	}
	else
	{
		$processor->add_message( "warning", $self->html_phrase( "no_changes" ) );
	}
}

sub render
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my( $page, $p, $div, $link );

	$page = $session->make_doc_fragment;

	my $searchexp = $self->get_searchexp;

	if( !defined $searchexp )
	{
		$processor->add_message( "error", $self->html_phrase( "invalid_cache" ) );
		return $page;
	}

	my $list = $searchexp->perform_search;

	if( $list->count == 0 )
	{
		$processor->add_message( "error", $session->html_phrase( "lib/searchexpression:noresults" ) );
		return $page;
	}

	$p = $session->make_element( "p" );
	$page->appendChild( $p );
	$p->appendChild( $searchexp->render_description );

	$p = $session->make_element( "p" );
	$page->appendChild( $p );
	$p->appendChild( $session->make_text(
		"Applying batch alterations to " . $list->count . " items (first 5 shown):"
	) );

	my $ul = $session->make_element( "ul" );
	$p->appendChild( $ul );

	my @eprints = $list->get_records( 0, 5 );
	foreach my $eprint (@eprints)
	{
		my $li = $session->make_element( "li" );
		$ul->appendChild( $li );
		$li->appendChild( $eprint->render_citation_link( ) );
	}

	$page->appendChild( $self->render_changes_form( $searchexp ) );


	return $page;
}

sub get_fields
{
	my( $self, $dataset ) = @_;

	my @fields;

	foreach my $field ($dataset->get_fields)
	{
		next if defined $field->{sub_name};
#		next if $field->is_type( "set", "namedset", "subject" );
		next if grep { $field->get_name eq $_ } @IGNORE_FIELDS;

		push @fields, $field;
	}

	return @fields;
}

sub get_changes
{
	my( $self, $dataset ) = @_;

	my %changes;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	foreach my $field ($self->get_fields( $dataset ))
	{
		my $action = $field->get_name . "_action";
		$action = $session->param( $action );
		if( $action )
		{
			local $field->{multiple};
			my $value;
			if( $field->get_property( "multiple" ) )
			{
				$field->{multiple} = 0;
			}
			if( $field->is_type( "compound", "multilang" ) )
			{
				$value = $field->form_value( $session );
			}
			else
			{
				$value = $field->form_value( $session, undef, $field->get_name );
			}
			$changes{ $field->get_name } = {
				action => $action,
				value => $value,
			};
		}
	}
	
	return %changes;
}

sub render_changes_form
{
	my( $self, $searchexp ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my( $page, $p, $div, $link );

	$page = $session->make_doc_fragment;

	my $dataset = $searchexp->get_dataset;

	my @input_fields;

	foreach my $field ($self->get_fields( $dataset ))
	{
		$field = $field->clone;
		my @options;
		if( $field->get_property( "multiple" ) )
		{
			@options = qw( clear delete insert append );
		}
		else
		{
			@options = qw( clear replace );
		}

		my $custom_field = {
			name => $field->get_name,
			type => "compound",
			fields => [{
				name => "batchedit_action",
				sub_name => "action",
				type => "set",
				options => \@options,
			}],
		};

		if( $field->is_type( "compound", "multilang" ) )
		{
			push @{$custom_field->{fields}}, @{$field->{fields}};
		}
		else
		{
			delete $field->{"multiple"};
			$field->{sub_name} = $field->{name};
			push @{$custom_field->{fields}}, $field;
		}

		$custom_field = $self->custom_field_to_field( $dataset, $custom_field );

		push @input_fields, $custom_field;
	}

	my %buttons = (
		edit => "Apply Changes",
	);

	my $form = $session->render_input_form(
		dataset => $dataset,
		fields => \@input_fields,
		show_help => 0,
		show_names => 1,
		top_buttons => \%buttons,
		buttons => \%buttons,
		hidden_fields => {
			screen => $processor->{screenid},
			cache => $searchexp->get_cache_id,
		},
	);

	$page->appendChild( $form );

	return $page;
}

sub custom_field_to_field
{
	my( $self, $dataset, $data ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	$data->{fields_cache} = [];

	foreach my $inner_field (@{$data->{fields}})
	{
		my $field = EPrints::MetaField->new(
			dataset => $dataset,
			parent_name => $data->{name},
			show_in_html => 0,
			%{$inner_field},
		);
		push @{$data->{fields_cache}}, $field;
	}

	my $field = EPrints::MetaField->new(
		dataset => $dataset,
		%{$data},
	);

	return $field;
}

sub cmp_deeply
{
	my( $var_a, $var_b ) = @_;

	if( !EPrints::Utils::is_set($var_a) )
	{
		return 0;
	}
	elsif( !EPrints::Utils::is_set($var_b) )
	{
		return -1;
	}

	my $rc = 0;

	$rc ||= ref($var_a) cmp ref($var_b);
	$rc ||= _cmp_hash($var_a, $var_b) if( ref($var_a) eq "HASH" );
	$rc ||= $var_a cmp $var_b if( ref($var_a) eq "" );

	return $rc;
}

sub _cmp_hash
{
	my( $var_a, $var_b ) = @_;

	my $rc = 0;

	for(keys %$var_a)
	{
		$rc ||= cmp_deeply( $var_a->{$_}, $var_b->{$_} );
	}

	return $rc;
}

1;
