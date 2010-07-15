if( EPrints::Utils::require_if_exists( "Search::Xapian" ) )
{
$c->{plugins}->{"Search::Xapian"}->{params}->{disable} = 0;

$c->add_trigger( EP_TRIGGER_INDEX_FIELDS, sub {
	my( %params ) = @_;

	my $repo = $params{repository};
	my $dataobj = $params{dataobj};
	my $dataset = $dataobj->dataset;
	my $fields = $params{fields};

	if( !defined $repo->{_xapian} )
	{
		my $path = $repo->config( "variables_path" ) . "/xapian";
		if( !-d $path )
		{
			EPrints->system->mkdir( $path );
		}
		$repo->{_xapian} = eval { Search::Xapian::WritableDatabase->new(
			$path,
			Search::Xapian::DB_CREATE_OR_OPEN()
		) };
		$repo->log( $@ ), return if $@;
	}
	my $db = $repo->{_xapian};

	my $tg = Search::Xapian::TermGenerator->new();
	my $doc = Search::Xapian::Document->new();

	$tg->set_stemmer( Search::Xapian::Stem->new( "english" ) );
	$tg->set_stopper( Search::Xapian::SimpleStopper->new() );
	$tg->set_document( $doc );

	$doc->add_term( "_dataset:" . $dataobj->{dataset}->base_id, 0 );
	$doc->set_data( $dataobj->id );

	my %field_pos;
	my $max_pos = 0;
	foreach my $langid (@{$repo->config( "languages" )})
	{
		foreach my $field ($dataset->fields)
		{
			my $name = $field->name;
			my $key = $dataset->id . '.' . $name . '.' . $langid;
			$field_pos{$key} = $db->get_metadata( $key ) || 0;
			$max_pos = $field_pos{$key} if $field_pos{$key} > $max_pos;
		}
		foreach my $name (keys %field_pos)
		{
			next if $field_pos{$name};
			my $key = $dataset->id . '.' . $name . '.' . $langid;
			$db->set_metadata( $key, $field_pos{$key} = ++$max_pos );
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
			$tg->index_text( $value, .5 );
			$tg->increase_termpos();
			if( $field->isa( "EPrints::MetaField::Text" ) )
			{
				$tg->index_text( $value, 1, $prefix );
				$tg->increase_termpos();
			}
			else
			{
				$doc->add_term( $prefix . $value );
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
			my $key = $dataset->id . '.' . $field->name . '.' . $langid;
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
				open(my $fh, "<:utf8", "$tempdir/$fn") or next FILE;
				my $chars = 0;
				while(<$fh>)
				{
					$chars += length($_);
					last if $chars > 2 * 1024 * 1024;
					$tg->index_text( $_ );
				}
				close($fh);
				$tg->increase_termpos();
			}
		}
	}

	my $key = $dataset->get_key_field->name . ':' . $dataobj->id;
	$db->replace_document_by_term( $key, $doc );
});


} # End of require_if_exists
