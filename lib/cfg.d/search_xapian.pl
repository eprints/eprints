if( EPrints::Utils::require_if_exists( "Search::Xapian" ) )
{
my $FLUSH_LIMIT = 1000;

$c->add_trigger( EP_TRIGGER_INDEX_FIELDS, sub {
	my( %params ) = @_;

	my $repo = $params{repository};
	my $dataobj = $params{dataobj};
	my $dataset = $dataobj->dataset;
	my $fields = $params{fields};

	if( !exists $repo->{_xapian} || $repo->{_xapian_limit}++ > $FLUSH_LIMIT )
	{
		$repo->{_xapian} = undef;
		$repo->{_xapian_limit} = 0;

		# if plugin disabled, don't continue
		my $plugin = $repo->plugin( "Search::Xapian" );
		return if !defined $plugin;

		my $path = $repo->config( "variables_path" ) . "/xapian";
		EPrints->system->mkdir( $path ) if !-d $path;

		$repo->{_xapian} = eval { Search::Xapian::WritableDatabase->new(
			$path,
			Search::Xapian::DB_CREATE_OR_OPEN()
		) };
		$repo->log( $@ ), return if $@;
	}

	my $db = $repo->{_xapian};
	return if !defined $db;

	if( !defined $repo->{_xapian_tg} )
	{
		my $plugin = $repo->plugin( "Search::Xapian" );

		$repo->{_xapian_tg} = Search::Xapian::TermGenerator->new();
		$repo->{_xapian_stemmer} = $plugin->stemmer;
		$repo->{_xapian_stopper} = $plugin->stopper;

		my $tg = $repo->{_xapian_tg};
		$tg->set_stemmer( $repo->{_xapian_stemmer} );
		$tg->set_stopper( $repo->{_xapian_stopper} );
	}

	my $tg = $repo->{_xapian_tg};
	$tg->set_termpos( 1 );

	my $doc = Search::Xapian::Document->new();
	$tg->set_document( $doc );

	my $key = "_id:" . $dataobj->internal_uri;

	$doc->add_term( "_dataset:" . $dataobj->{dataset}->base_id, 0 );
	$doc->add_term( $key, 0 );
	$doc->set_data( $dataobj->id );

	my %field_pos;
	my $max_pos = 0;
	foreach my $langid (@{$repo->config( "languages" )})
	{
		foreach my $field ($dataset->fields)
		{
			my $name = $field->name;
			my $key = $dataset->base_id . '.' . $name . '.' . $langid;
			$field_pos{$key} = $db->get_metadata( $key ) || 0;
			$max_pos = $field_pos{$key} if $field_pos{$key} > $max_pos;
		}
		foreach my $key (keys %field_pos)
		{
			next if $field_pos{$key};
			$db->set_metadata( $key, "" . ($field_pos{$key} = ++$max_pos) );
		}
	}

	foreach my $field ($dataobj->dataset->fields)
	{
		next if $field->isa( "EPrints::MetaField::Compound" );
		next if $field->isa( "EPrints::MetaField::Langid" );
		next if $field->isa( "EPrints::MetaField::Subobject" );
		next if $field->isa( "EPrints::MetaField::Storable" );

		my $prefix = $field->name . ':';
		my $value = $field->get_value( $dataobj );
		next if !EPrints::Utils::is_set( $value );
		foreach my $v ($field->property( "multiple" ) ? @$value : $value)
		{
			my $value;
			if( $field->isa( "EPrints::MetaField::Name" ) )
			{
				$value = join(' ', @$v{qw( given family )});
			}
			else
			{
				$value = $v;
			}
			next if !EPrints::Utils::is_set( $value );
			$tg->index_text( $value );
			$tg->increase_termpos();
			
			# Allow indexing of long text fields (e.g. abstracts that are longer than 200 chars)
			# The Xapian length limit applies to only a single term with 200 consecutive chars without white-space
			# next if length($value) > 200; # Xapian term length limit-ish
			if( $field->isa( "EPrints::MetaField::Text" ) || $field->isa( "EPrints::MetaField::Name" ) )
			{
				$tg->index_text( $value, 2, $prefix );
				$tg->increase_termpos();
			}
			else
			{
				# Improve indexing: Long term values must be filtered
				# Dates are stripped to year only and are added with wdf = 0
				# This enables that records are correctly sorted by date
				next if length($value) > 200; # Xapian term length limit-ish

				if ($field->name eq 'date')
				{
					$value =~ /^(\d{4})/;
					$doc->add_boolean_term( $prefix . $value );
				}
				else 
				{
					$doc->add_term( $prefix . $value );
				}
			}
		}
		foreach my $langid (@{$repo->config( "languages" )})
		{
			my $ordervalue = $field->ordervalue(
				$value,
				$repo,
				$langid, # TODO: non-English ordervalues?
				$dataset
			);
			my $key = $dataset->base_id . '.' . $field->name . '.' . $langid;
			$doc->add_value( $field_pos{$key}, $ordervalue );
		}
	}

	# Fulltext
	if( $dataset->base_id eq "eprint" )
	{
		my $convert = $repo->plugin( "Convert" );
		my $tempdir = File::Temp->newdir();
		DOC: foreach my $doc ($dataobj->get_all_documents)
		{
			my $type = "text/plain";
			my %types = $convert->can_convert( $doc, $type );
			next DOC if !exists $types{$type};
			my $plugin = $types{$type}->{plugin};
			FILE: foreach my $fn ($plugin->export( $tempdir, $doc, $type ))
			{
				open(my $fh, "<", "$tempdir/$fn") or next FILE;
				sysread($fh, my $buffer, 2 * 1024 * 1024);
				close($fh);
				$tg->index_text( Encode::decode_utf8( $buffer ) );
				$tg->increase_termpos();
			}
		}
	}

	$db->replace_document_by_term( $key, $doc );
});

$c->add_trigger( EP_TRIGGER_INDEX_REMOVED, sub {
	my( %params ) = @_;

	my $repo = $params{repository};
	my $dataset = $params{dataset};
	my $id = $params{id};

	if( !exists $repo->{_xapian} )
	{
		$repo->{_xapian} = undef;
		$repo->{_xapian_limit} = 0;

		# if plugin disabled, don't continue
		return if !defined $repo->plugin( "Search::Xapian" );

		my $path = $repo->config( "variables_path" ) . "/xapian";
		EPrints->system->mkdir( $path ) if !-d $path;

		$repo->{_xapian} = eval { Search::Xapian::WritableDatabase->new(
			$path,
			Search::Xapian::DB_CREATE_OR_OPEN()
		) };
		$repo->log( $@ ), return if $@;
	}

	my $db = $repo->{_xapian};
	return if !defined $db;

	my $key = "_id:/id/" . $dataset->base_id . "/" . $id;
	my $enq = $db->enquire( Search::Xapian::Query->new( $key ) );
	my @matches = $enq->matches( 0, 1 );
	if( @matches )
	{
		$db->delete_document( $matches[0]->get_docid );
	}
});



} # End of require_if_exists
