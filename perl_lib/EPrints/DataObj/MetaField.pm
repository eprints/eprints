######################################################################
#
# EPrints::DataObj::MetaField
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################


=head1 NAME

B<EPrints::DataObj::MetaField> - metadata fields

=head1 DESCRIPTION

This is an internal class that shouldn't be used outside L<EPrints::Database>.

=head1 METHODS

=over 4

=cut

package EPrints::DataObj::MetaField;

@ISA = ( 'EPrints::DataObj' );

use EPrints::MetaField;

use EPrints;

use strict;

=item $thing = EPrints::DataObj::MetaField->get_system_field_info

Core fields.

=cut

sub get_system_field_info
{
	my( $class ) = @_;

	return
	( 
		{ name=>"metafieldid", type=>"text", required=>1, },

		{ name=>"mfdatestamp", type=>"timestamp", required=>1, },

		{ name=>"mfstatus", type=>"set", required=>1,
			options => [qw( inbox archive deletion )],
		},

		{ name=>"mfdatasetid", type=>"namedset", required=>1, input_rows=>1,
			set_name => "datasets",
		},

		{ name=>"phrase_name", type=>"multilang", multiple=> 1, required=>0,
			fields => [
				{ sub_name=>"text", type=>"text", }
		]},

		{ name=>"phrase_help", type=>"multilang", multiple => 1, required=>0,
			fields => [
				{ sub_name=>"text", type=>"longtext", }
		]},

		{ name=>"name", type=>"text", required=>1, input_cols=>10 },

		{ name=>"type", type=>"set", required=>1,
			input_style => "long",
			options => [&_get_field_types],
		},

		{ name=>"providence", type=>"set", required=>1,
			options => [qw( core config user )],
		},

		{
			name => "fields",
			type => "compound",
			multiple => 1,
			fields => [
				{ sub_name=>"mfremoved", type=>"boolean", },

				{ sub_name=>"sub_name", type=>"text", required=>1, input_cols=>10 },

				{ sub_name=>"type", type=>"set", required=>1,
					input_style => "long",
					options => [&_get_sub_field_types],
				},

				&_get_property_sub_fields,
			],
		},

		&_get_property_fields,
	);
}

sub _get_property_sub_fields
{
	return
		map { $_->{sub_name} = delete $_->{name}; $_ }
		grep { $_->{name} ne "multiple" }
		&_get_property_fields;
}

sub _get_property_fields
{
	return (
		{ name=>"required", type=>"boolean", input_style => "menu", },
		{ name=>"multiple", type=>"boolean", input_style => "menu", },
		{ name=>"allow_null", type=>"boolean", input_style => "menu", },
		{ name=>"export_as_xml", type=>"boolean", input_style => "menu", },
		{ name=>"volatile", type=>"boolean", input_style => "menu", },

		{ name=>"min_resolution", type=>"set",
			options => [qw( year month day hour minute second )],
		},

		{ name=>"sql_index", type=>"boolean", input_style => "menu", },

		{ name=>"render_input", type=>"text" },
		{ name=>"render_value", type=>"text" },

		{ name=>"input_ordered", type=>"boolean", input_style => "menu", },

		{ name=>"maxlength", type=>"int", input_cols => 5, },

		{ name=>"browse_link", type=>"text", input_cols=>10, },
		{ name=>"top", type=>"text", input_cols=>10, },

		{ name=>"datasetid", type=>"text", input_cols=>10, },

		{ name=>"set_name", type=>"text", input_cols=>10, },
		{ name=>"options", type=>"text", },

		{ name=>"render_order", type=>"set", input_rows=>1,
			options => [qw( fg gf )]
		},
		{ name=>"hide_honourific", type=>"boolean", input_style => "menu", input_rows=>1, },
		{ name=>"hide_lineage", type=>"boolean", input_style => "menu", input_rows=>1, },
		{ name=>"family_first", type=>"boolean", input_style => "menu", input_rows=>1, },

		{ name=>"input_style", type=>"set",
			options => [qw( menu radio long medium short )],
		},
		{ name=>"input_rows", type=>"int", input_cols=>3, },
		{ name=>"input_cols", type=>"int", input_cols=>3, },
		{ name=>"input_boxes", type=>"int", input_cols=>3, },

		{ name=>"sql_counter", type=>"text", sql_index=>0 },
		{ name=>"default_value", type=>"text", sql_index=>0 },
	);
}

sub _get_sub_field_types
{
	my @types = &_get_field_types;

	@types = grep { $_ ne "compound" and $_ ne "multilang" } @types;

	return @types;
}

sub _get_field_types
{
	my @types;

	return qw(
			arclanguage
			boolean
			compound
			counter
			date
			email
			float
			int
			itemref
			longtext
			multilang
			name
			namedset
			pagerange
			search
			secret
			set
			subject
			text
			time
			timestamp
			url
	);
}

######################################################################

=back

=head2 Constructor Methods

=over 4

=cut

######################################################################

=item $thing = EPrints::DataObj::MetaField->new( $session, $metafieldid )

Return the data object identified by $metafieldid.

=cut

=item $thing = EPrints::DataObj::MetaField->new_from_data( $session, $known )

Create a new C<EPrints::DataObj::MetaField> object containing data $known (a hash reference).

=cut

# The configuration uses "1" and "0" but the database uses "TRUE" and "FALSE"
# This papers over the cracks
our %BOOLEAN = (
	1 => 1,
	0 => 0,
	"TRUE" => 1,
	"FALSE" => 0,
);
our %RBOOLEAN = (
	1 => "TRUE",
	0 => "FALSE",
	"TRUE" => "TRUE",
	"FALSE" => "FALSE",
);

sub new_from_data
{
	my( $class, $session, $known ) = @_;

	my $dataset = $session->get_repository->get_dataset( "metafield" );

	# strip unsupported properties
	for(keys %$known)
	{
		delete $known->{$_} unless $dataset->has_field( $_ );
	}
	foreach my $sub_field (@{$known->{fields}||[]})
	{
		for(keys %$sub_field)
		{
			delete $sub_field->{$_} unless $dataset->has_field( "fields_$_" );
		}
	}

	# 1/0 => TRUE/FALSE
	foreach my $epdata ($known,@{$known->{fields}||[]})
	{
		while(my( $name, $value ) = each %$epdata)
		{
			# can't get_field() on inner-field specific entries
			next if $name eq "sub_name";
			# mfremoved should never appear in configuration
			next if $name eq "mfremoved";
			next unless EPrints::Utils::is_set($value); # nothing to do
			my $field = $dataset->get_field( $name );
			next unless $field->isa( "EPrints::MetaField::Boolean" );
			if( $field->get_property( "multiple" ) )
			{
				($_ = defined($_) ? $RBOOLEAN{$_} : $_) for @$value;
			}
			else
			{
				$epdata->{$name} = $RBOOLEAN{$value};
			}
		}
	}

	# store options as text
	for($known,@{$known->{fields}||[]})
	{
		next if !exists($_->{options}) or ref($_->{options}) ne "ARRAY";
		$_->{options} = join(",", @{$_->{options}});
	}

	return $class->SUPER::new_from_data(
			$session,
			$known,
			$dataset );
}

######################################################################

=head2 Class Methods

=cut

######################################################################

=item $path = EPrints::DataObj::MetaField->get_config_path( $session )

Returns the root directory of the repository configuration path.

=cut

sub get_config_path
{
	my( $class, $session ) = @_;

	return $session->get_repository->get_conf("config_path");
}

######################################################################
=pod

=item $dataset = EPrints::DataObj::MetaField->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut
######################################################################

sub get_dataset_id()
{
	return "metafield";
}

######################################################################

=item $defaults = EPrints::DataObj::MetaField->get_defaults( $session, $data )

Return default values for this object based on the starting data.

=cut

######################################################################

sub get_defaults
{
	my( $class, $session, $data, $dataset ) = @_;
	
	$class->SUPER::get_defaults( $session, $data, $dataset );

	if( $data->{name} and $data->{mfdatasetid} )
	{
		$data->{metafieldid} ||= "$data->{mfdatasetid}.$data->{name}";
	}

	$data->{"mfstatus"} = "inbox";

	# This is set by DataSet for core and config fields
	$data->{"providence"} = "user";

	return $data;
}

=item $filename = EPrints::DataObj::MetaField->get_perl_file_config( $session )

Returns the location of the Perl configuration file.

=cut

sub get_perl_file_config
{
	my( $class, $session ) = @_;

	return $session->get_repository->get_conf( "variables_path" )."/metafield.pl";
}

=item $filename = EPrints::DataObj::MetaField->get_phrases_filename( $session, $langid )

Returns the location of the XML phrases file for $lang.

=cut

sub get_phrases_filename
{
	my( $class, $session, $langid ) = @_;

	return $session->get_repository->get_conf( "config_path" )."/lang/$langid/phrases/zz_webcfg.xml";
}

=item $defaults = EPrints::DataObj::MetaField->get_property_defaults( $session, $type )

Gets the property defaults for metafield $type.

=cut

sub get_property_defaults
{
	my( $self, $session, $type ) = @_;

	my $field_defaults = $session->get_repository->get_field_defaults( $type );
	return $field_defaults if defined $field_defaults;

	my $class = $type;
	$class =~ s/[^a-zA-Z0-9_]//g; # don't let badness into eval()
	$class = "EPrints::MetaField::\u$class";
	eval "use $class;";
	if( $@ )
	{
		return undef;
	}

	my $prototype = bless {
			repository => $session->get_repository
		}, $class;

	return { $prototype->get_property_defaults };
}

=item $filename = EPrints::DataObj::MetaField->get_workflow_filename( $session, $datasetid )

Returns the location of the workflow file for $datasetid.

=cut

sub get_workflow_filename
{
	my( $self, $session, $datasetid ) = @_;

	return $session->get_repository->get_conf( "config_path" )."/workflows/$datasetid/default.xml";
}

=item $filename = EPrints::DataObj::MetaField->get_xml_file_config( $session )

Returns the location of the XML configuration file.

=cut

sub get_xml_file_config
{
	my( $class, $session ) = @_;

	return $session->get_repository->get_conf( "variables_path" )."/metafield.xml";
}

=item $list = EPrints::DataObj::MetaField::load_all( $session )

Populate the metafield dataset using the currently configured fields. Returns a L<EPrints::List> of the loaded meta fields.

=cut

sub load_all
{
	my( $session ) = @_;

	my $ds = $session->get_repository->get_dataset( "metafield" );
	my @datasetids = $session->get_repository->get_types( "datasets" );
	my $fields = $session->get_repository->get_conf( "fields" );

	my @ids;

	foreach my $datasetid (@datasetids)
	{
		my $dataset = $session->get_repository->get_dataset( $datasetid );

		my @field_data;

		push @field_data, $dataset->get_object_class->get_system_field_info;
		for(@field_data)
		{
			$_->{providence} = "core"; # must be core
		}

		push @field_data, @{$fields->{$datasetid}||[]};
		for(@field_data)
		{
			$_->{providence} ||= "config"; # may be config or user
		}

		foreach my $data (@field_data)
		{
			my $metafieldid = $dataset->confid.".".$data->{"name"};
			my $dataobj = $ds->get_object(
					$session,
					$metafieldid
					);
			if( defined($dataobj) )
			{
				$dataobj->remove;
			}
			$data = EPrints::Utils::clone( $data );
			$data->{mfstatus} = "archive";
			$data->{mfdatasetid} = $datasetid;
			$dataobj = $ds->create_object( $session, $data );
			push @ids, $dataobj->get_id;
		}
	}

	return EPrints::List->new(
		session => $session,
		dataset => $ds,
		ids => \@ids,
	);
}

=item EPrints::DataObj::MetaField::save_all( $session )

Save the user-configured fields.

=cut

sub save_all
{
	my( $session ) = @_;

	my $dataset = $session->get_repository->get_dataset( "metafield" );

	my $searchexp = EPrints::Search->new(
		session => $session,
		dataset => $dataset,
	);

	$searchexp->add_field( $dataset->get_field( "mfstatus" ), "archive" );
	$searchexp->add_field( $dataset->get_field( "providence" ), "user" );

	my $list = $searchexp->perform_search;

	my $xml_plugin = $session->plugin( "Export::XML" );

	my $file_name;
	my $fh;

	$file_name = __PACKAGE__->get_xml_file_config( $session );

	open($fh, ">", $file_name)
		or EPrints::abort "Can't write to $file_name: $!";
	$xml_plugin->output_list(
		list => $list,
		fh => $fh
	);
	close($fh);

	my $perl_plugin = $session->plugin( "Export::Perl" );

	$file_name = __PACKAGE__->get_perl_file_config( $session );

	open($fh, ">", $file_name)
		or EPrints::abort "Can't write to $file_name: $!";
	$perl_plugin->output_list(
		list => $list,
		fh => $fh
	);
	close($fh);
}

######################################################################

=head2 Object Methods

=cut

######################################################################

=item $ok = $mf->add_to_phrases()

Add the phrases defined by this field to the system.

=cut

sub add_to_phrases
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $ok = 1;

	my $name = $self->get_value( "name" );
	my $datasetid = $self->get_value( "mfdatasetid" );
	my $path = $self->get_config_path( $session ) . "/lang";

	my %phrases;

	foreach my $type (qw( name help ))
	{
		my $values = $self->get_value( "phrase_$type" );
		foreach my $phrase (@$values)
		{
			$phrase = EPrints::Utils::clone( $phrase );
			$phrase->{lang} ||= "en";
			my $name = "$datasetid\_field$type\_".$self->get_value( "name" );
			$phrases{$phrase->{lang}}->{$name} = $phrase->{text};
		}
	}

	# Add default phrases for sub-fields/options
	foreach my $field_data ($self->{data},@{$self->{data}->{fields}||[]})
	{
		my $type = $field_data->{"type"};
		my $field_name = $name;
		if( exists($field_data->{"sub_name"}) )
		{
			$field_name .= "_" . $field_data->{"sub_name"};
			foreach my $langid (keys %phrases)
			{
				my $phraseid = "$datasetid\_fieldname_$field_name";
				my $phrase = _opt_to_phrase($field_name);
				$phrases{$langid}->{$phraseid} = $phrase;
			}
		}
		if( $type eq "set" )
		{
			my @options = split /\s*,\s*/, ($field_data->{"options"}||"");
			for(@options)
			{
				my $phraseid = "$datasetid\_fieldopt_$field_name\_$_";
				my $phrase = _opt_to_phrase($_);
				foreach my $langid (keys %phrases)
				{
					$phrases{$langid}->{$phraseid} = $phrase;
				}
			}
		}
	}

	foreach my $langid (keys %phrases)
	{
		my $file_name = $self->get_phrases_filename( $session, $langid );
		my $doc;
		if( !-e $file_name )
		{
			$doc = $self->_phrases_empty();
		}
		else
		{
			$doc = $session->xml->parse_file( $file_name );
		}
		my $xml = EPrints::XML->new( $session, doc => $doc );
		my $phrases = $doc->documentElement;

		while(my( $name, $text ) = each %{$phrases{$langid}})
		{
			my $phrase = $xml->create_element( "epp:phrase", id => $name );
			my $html = eval { $xml->parse_xml_string( $text ) };
			if( defined $html )
			{
				$phrase->appendChild( $xml->clone( $html->documentElement ) );
				$xml->dispose( $html );
			}
			else
			{
				$phrase->appendChild( $xml->create_text_node( $text ) );
			}
			my $old_phrase;
			foreach my $node ($phrases->childNodes)
			{
				if( $xml->is( $node, "Element" ) &&
					$node->hasAttribute("id") &&
					$node->getAttribute("id") eq $name )
				{
					$old_phrase = $node;
					last;
				}
			}
			if( defined $old_phrase )
			{
				$phrases->replaceChild( $phrase, $old_phrase );
			}
			else
			{
				$phrases->appendChild( $xml->create_text_node( "\n\t" ) );
				$phrases->appendChild( $phrase );
			}
		}

		if( open(my $fh, ">", $file_name) )
		{
			binmode($fh, ":utf8");
			print $fh $xml->to_string( $doc );
			close($fh);
		}
		else
		{
			$session->get_repository->log( "Failed to open $file_name for writing: $!" );
			$ok = 0;
		}

		$xml->dispose( $doc );
	}

	return $ok;
}

=item $ok = $mf->add_to_workflow()

Add this field to the workflow in the "Misc." section.

=cut

sub add_to_workflow
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $ok = 1;

	my $datasetid = $self->get_value( "mfdatasetid" );

	my $file_name = $self->get_workflow_filename( $session, $datasetid );

	return $ok unless -e $file_name;

	my $doc = $session->xml->parse_file( $file_name );

	my $xml = EPrints::XML->new( $session, doc => $doc );
	my $workflow = $doc->documentElement;

	# return if this field is already referred to in the workflow
	foreach my $field ($workflow->getElementsByTagName( "field" ) )
	{
		if( $field->getAttribute( "ref" ) eq $self->get_value( "name" ) )
		{
			return $ok;
		}
	}

	my( $flow ) = $workflow->getElementsByTagName( "flow" );

	my $stage_ref;
	for($flow->childNodes)
	{
		if( $xml->is( $_, "Element" ) &&
			$_->hasAttribute( "ref" ) &&
			$_->getAttribute( "ref" ) eq "local"
		)
		{
			$stage_ref = $_;
			last;
		}
	}
	if( !defined( $stage_ref ) )
	{
		$stage_ref = $xml->create_element( "stage",
			ref => "local"
		);
		$flow->appendChild( $stage_ref );
		$flow->appendChild( $xml->create_text_node( "\n\t" ) );
	}

	my $stage;
	for($workflow->childNodes)
	{
		if( $xml->is( $_, "Element" ) &&
			$_->hasAttribute( "name" ) &&
			$_->getAttribute( "name" ) eq "local"
		)
		{
			$stage = $_;
			last;
		}
	}

	if( !defined( $stage ) )
	{
		$stage = $xml->create_element( "stage",
			name => "local"
		);
		$stage->appendChild( $xml->create_text_node( "\n\t" ) );
		$workflow->appendChild( $xml->create_text_node( "\t" ) );
		$workflow->appendChild( $stage );
		$workflow->appendChild( $xml->create_text_node( "\n\n" ) );
	}

	my $component = $xml->create_element( "component" );
	my $field = $xml->create_element( "field",
		ref => $self->get_value( "name" )
	);
	$stage->appendChild( $xml->create_text_node( "\t" ) );
	$stage->appendChild( $component );
	$stage->appendChild( $xml->create_text_node( "\n\t" ) );
	$component->appendChild( $field );

	if( open(my $fh, ">", $file_name) )
	{
		binmode($fh, ":utf8");
		print $fh $xml->to_string($doc);
		close($fh);
	}
	else
	{
		$session->get_repository->log( "Failed to open $file_name for writing: $!" );
		$ok = 0;
	}

	return $ok;
}

=item $data = $field->get_perl_struct

Returns the Perl data structure representation of this field, as you would find defined in the configuration or DataObj classes.

=cut

sub get_perl_struct
{
	my( $self ) = @_;

	my $dataset = $self->{dataset};

	my $data = {};

	foreach my $field ($dataset->get_fields)
	{
		next if defined $field->get_property( "sub_name" );
		next if
			$field->get_name eq "metafieldid" or
			$field->get_name eq "mfdatasetid" or
			$field->get_name eq "mfdatestamp" or
			$field->get_name eq "mfstatus" or
			$field->get_name eq "phrase_name" or
			$field->get_name eq "phrase_help"
			;
		my $value = $field->get_value( $self );
		if( EPrints::Utils::is_set( $value ) )
		{
			$data->{$field->get_name} = $value;
		}
	}

	# TRUE/FALSE => 1/0
	foreach my $epdata ($data,@{$data->{fields}||[]})
	{
		while(my( $name, $value ) = each %$epdata)
		{
			# can't get_field() on inner-field specific entries
			next if $name eq "sub_name";
			# mfremoved should never appear in configuration
			next if $name eq "mfremoved";
			next unless EPrints::Utils::is_set($value); # nothing to do
			my $field = $dataset->get_field( $name );
			next unless $field->isa( "EPrints::MetaField::Boolean" );
			if( $field->get_property( "multiple" ) )
			{
				($_ = defined($_) ? $BOOLEAN{$_} : $_) for @$value;
			}
			else
			{
				$epdata->{$name} = $BOOLEAN{$value};
			}
		}
	}

	# Fix for document.main (options => [])
	if( $data->{type} eq "set" && !defined $data->{options} )
	{
		$data->{options} = "";
	}

	foreach my $field_data ($data,@{$data->{fields}||[]})
	{
		# Remove unused properties (avoid warnings)
		my $defaults = $self->get_property_defaults( $self->{session}, $field_data->{type} );
		foreach my $property (keys %$field_data)
		{
			if( !defined $defaults->{$property} )
			{
				delete $field_data->{$property};
			}
		}

		# Split options text
		if( defined( $field_data->{options} ) )
		{
			$field_data->{options} = [split /\s*,\s*/, $field_data->{options}];
		}
	}

	return $data;
}

# The initial phrases file (sorry, English only)
sub _phrases_empty
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $doc = $session->get_lang->create_phrase_doc( $session );
	my $phrases = $doc->documentElement;

	my $phrase = $doc->createElement( "epp:phrase" );
	$phrase->setAttribute( id=>"metapage_title_local" );
	$phrase->appendChild( $doc->createTextNode( "Misc." ) );

	$phrases->appendChild( $phrase );

	return $doc;
}

# convert an option to a phrase - this is just for convenience
sub _opt_to_phrase
{
	my( $name ) = @_;

	$name =~ s/_/ /g;
	$name =~ s/\b(\w)/\u$1/g;

	return $name;
}

=item $field = $mf->make_field_object();

Make and return a new field object based on this metafield.

=cut

sub make_field_object
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $datasetid = $self->get_value( "mfdatasetid" );
	my $dataset = $session->get_repository->get_dataset( $datasetid );

	my $fielddata = $self->get_perl_struct();

	if( !defined $fielddata->{type} )
	{
		$session->get_repository->log( "Error in metafield entry ".$self->get_id.": no type defined" );
		return undef;
	}

	my @cfields;
	if( $fielddata->{type} eq "compound" )
	{	
		@cfields = @{$fielddata->{fields}};
	}
	if( $fielddata->{type} eq "multilang" )
	{	
		my $langs = $self->{repository}->get_conf('languages');
		if( defined $fielddata->{languages} )
		{
			$langs = $fielddata->{languages};
		}
		@cfields = (
			@{$fielddata->{fields}},
			{ 
				sub_name=>"lang",
				type=>"langid",
				options => $langs,
			}, 
		);
	}
		
	if( scalar @cfields )
	{	
		$fielddata->{fields_cache} = [];
		foreach my $inner_field ( @cfields )
		{
			my $field = EPrints::MetaField->new( 
				parent_name => $fielddata->{name},
				show_in_html => 0,
				dataset => $dataset, 
				multiple => $fielddata->{multiple},
				%{$inner_field} );	
			push @{$fielddata->{fields_cache}}, $field;
		}
	}

	my $field = EPrints::MetaField->new( 
		dataset => $dataset, 
		%{$fielddata} );	

	return $field;
}

# unsupported
sub move_to_inbox
{
	my( $self ) = @_;

	$self->set_value( "mfstatus", "inbox" );
	$self->commit( 1 );

	return 1;
}

=item $mf->move_to_archive()

Adds this field to the target dataset and adds the necessary database bits.

=cut

sub move_to_archive
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $ds = $self->get_dataset;

	my $datasetid = $self->get_value( "mfdatasetid" );
	my $dataset = $session->get_repository->get_dataset( $datasetid );

	my $field = $self->make_field_object();

	# sort out the inner fields in compound fields
	if( $field->isa( "EPrints::MetaField::Compound" ) )
	{
		my $prefix = $field->get_name . "_";
		my $inner_fields = $self->get_value( "fields" );
		my( @removed, @current );
		foreach my $inner_field (@$inner_fields)
		{
			if( $inner_field->{"mfremoved"} ne "TRUE" )
			{
				push @current, $inner_field;
			}
			else
			{
				push @removed, $inner_field;
			}
		}
		$self->set_value( "fields", \@current );
		# remove any instances of fields we're about consume
		foreach my $inner_field (@current)
		{
			my $name = $prefix . $inner_field->{sub_name};
			if( $dataset->has_field( $name ) )
			{
				$dataset->unregister_field( $dataset->get_field( $name ) );
			}

			my $inner_metafield = $ds->get_object( $session, "$datasetid.$name" );
			if( defined $inner_metafield )
			{
				$inner_metafield->remove;
			}
		}
		# spin-off any fields that we're no longer using
		foreach my $inner_field (@removed)
		{
			my $name = $prefix . $inner_field->{sub_name};
			$inner_field->{name} = $name;
			delete $inner_field->{sub_name};
			delete $inner_field->{mfremoved};

			if( !$dataset->has_field( $name ) )
			{
				$dataset->process_field( $inner_field );
			}

			my $inner_metafield = $ds->get_object( $session, "$datasetid.$name" );
			if( !defined $inner_metafield )
			{
				$inner_field->{"mfstatus"} = $self->get_value( "mfstatus" );
				$inner_field->{"mfdatasetid"} = $self->get_value( "mfdatasetid" );
				$ds->create_object( $session, $inner_field );
			}
		}
		if( scalar(@current) == 0 )
		{
			$self->commit( 1 );
			return 0;
		}
	}

	my $conf = $self->get_perl_struct;

	$field = $dataset->process_field( $conf, 0 );

	# add to the user configuration
	my $fields = $session->get_repository->get_conf( "fields" );
	push @{$fields->{$datasetid}||=[]}, $conf;

	# add to the database (force changes)
	$session->get_database->add_field( $dataset, $field, 1 );

	$self->set_value( "mfstatus", "archive" );
	$self->commit( 1 );

	return 1;
}

sub move_to_deletion
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $datasetid = $self->get_value( "mfdatasetid" );
	my $dataset = $session->get_repository->get_dataset( $datasetid );
	my $name = $self->get_value( "name" );

	my $field = $dataset->get_field( $name );

	# remove the field from the dataset
	$dataset->unregister_field( $field );

	# remove the field from the current session
	my $fieldconf = $session->get_repository->get_conf( "fields", $datasetid );
	if( defined $fieldconf )
	{
		@{$fieldconf} = grep { $_->{name} ne $name } @{$fieldconf};
	}

	$session->get_database->remove_field( $dataset, $field );

	$self->remove();

	return 1;
}

=item $ok = $mf->remove_from_workflow()

Remove all occurrences of this field from the workflow. Will remove the "local" stage if it is empty.

=cut

sub remove_from_workflow
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $ok = 1;

	my $datasetid = $self->get_value( "mfdatasetid" );
	my $name = $self->get_value( "name" );

	my $file_name = $self->get_workflow_filename( $session, $datasetid );

	return $ok unless -e $file_name;

	my $doc = $session->xml->parse_file( $file_name );

	my $workflow = $doc->documentElement;

	my( $flow ) = $workflow->getElementsByTagName( "flow" );

	# find and remove all occurrences of the $name field
	foreach my $field ($workflow->getElementsByTagName( "field" ))
	{
		if(
			$field->hasAttribute( "ref" ) and
			$field->getAttribute( "ref" ) eq $name
		)
		{
			my $component = $field->parentNode;
			$component->removeChild( $field );
			# remove the component as well if it doesn't contain any other
			# fields
			if( $component->getElementsByTagName( "field" )->length == 0 )
			{
				$component->parentNode->removeChild( $component );
			}
		}
	}

	my $remove_local = 0;

	# if the "local" stage contains no components or fields, remove it
	foreach my $stage ($workflow->getElementsByTagName( "stage" ))
	{
		if(
			$stage->hasAttribute( "name" ) and
			$stage->getAttribute( "name" ) eq "local"
		)
		{
			if( $stage->getElementsByTagName( "component" )->length == 0 and
				$stage->getElementsByTagName( "field" )->length == 0
			)
			{
				$workflow->removeChild( $stage );
				$remove_local = 1;
			}
			last;
		}
	}

	# remove the reference to the local stage if we deleted it
	if( $remove_local )
	{
		foreach my $stage ( $flow->getElementsByTagName( "stage" ) )
		{
			if(
				$stage->hasAttribute( "ref" ) and
				$stage->getAttribute( "ref" ) eq "local"
			)
			{
				$flow->removeChild( $stage );
				last;
			}
		}
	}

	open(my $fh, ">", $file_name) or EPrints::abort "Failed to open $file_name for writing: $!";
	binmode($fh, ":utf8");
	print $fh $session->xml->to_string( $doc );
	close($fh);

	$session->xml->dispose( $doc );

	return $ok;
}

=item $problems = $mf->validate( $repository )

Return any problems associated with this metafield.

=cut

sub validate
{
	my( $self, $repository ) = @_;

	my @problems;

	for($self->{data}, @{$self->{data}->{fields}||[]})
	{
		push @problems, $self->_validate_epdata( $_ );
	}

	return \@problems;
}

sub _validate_epdata
{
	my( $self, $epdata ) = @_;

	my $session = $self->get_session;

	my @problems;

	if( !defined $epdata->{"type"} )
	{
		push @problems, $session->html_phrase(
				"validate:missing_type",
			);
		return @problems;
	}

	my $field_defaults = $self->get_property_defaults( $session, $epdata->{type} );

	if( !defined $field_defaults )
	{
		push @problems, $session->html_phrase(
				"validate:bad_type",
				type => $session->make_text( $epdata->{type} ),
			);
		return @problems;
	}

	foreach my $property (keys %$field_defaults)
	{
		next if $property eq "fields_cache";
		next if $property eq "fields";
		if( $field_defaults->{$property} eq $EPrints::MetaField::REQUIRED && !EPrints::Utils::is_set( $epdata->{$property} ) )
		{
			push @problems, $session->html_phrase(
					"validate:missing_property",
					property => $session->make_text( $property )
				);
		}
	}

	# fields is expanded out in $epdata, so we need to actually look for
	# fields_sub_name
	if( exists $field_defaults->{"fields"} && $field_defaults->{"fields"} eq $EPrints::MetaField::REQUIRED && !EPrints::Utils::is_set( $epdata->{"fields_sub_name"} ) )
	{
		push @problems, $session->html_phrase(
				"validate:missing_property",
				property => $session->make_text( "fields" )
			);
	}

	if( $epdata->{"type"} eq "itemref" )
	{
		my $datasetid = $epdata->{"datasetid"};
		$datasetid = "" unless defined $datasetid;

		unless( $session->get_repository->get_dataset( $datasetid ) )
		{
			push @problems, $session->html_phrase(
					"validate:unknown_datasetid",
					datasetid => $session->make_text( $datasetid ),
				);
		}
	}

	return @problems;
}

1;

__END__

=back

=head1 SEE ALSO

L<EPrints::DataObj> and L<EPrints::DataSet>.

=cut

