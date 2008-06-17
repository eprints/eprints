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

		{ name=>"mfdatestamp", type=>"time", required=>1, },

		{ name=>"mfstatus", type=>"set", required=>1,
			options => [qw( inbox archive deletion )],
		},

		{ name=>"mfdatasetid", type=>"set", required=>1, input_rows=>1,
			options => [&get_valid_datasets],
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
			url
	);

	my $base_path = $EPrints::SystemSettings::conf->{base_path};
	my $path = "$base_path/perl_lib/EPrints/MetaField";

	opendir(DIR, $path) or die "$path: $!";
	my @modules = grep { /^[^\.]/ and /\.pm$/ } readdir(DIR);
	closedir(DIR);

	for(@modules)
	{
		$_ = lc($_);
		$_ =~ s/\.pm$//;
		push @types, $_;
	}

	@types = sort { $a cmp $b } @types;

	return @types;
}

######################################################################

=back

=head2 Constructor Methods

=over 4

=cut

######################################################################

=item $thing = EPrints::DataObj::MetaField->new( $session, $metafieldid )

The data object identified by $metafieldid.

=cut

sub new
{
	my( $class, $session, $metafieldid ) = @_;

	return $session->get_database->get_single( 
			$session->get_repository->get_dataset( "metafield" ), 
			$metafieldid );

	my( $datasetid, $name ) = split /\./, $metafieldid, 2;

	unless( $datasetid =~ /^document|eprint|user$/ )
	{
		return undef;
	}

	my $eprint_fields = $session->get_repository->get_conf( "fields", $datasetid );
	$eprint_fields ||= [];

	for(@{$eprint_fields})
	{
		if( $_->{name} eq $name )
		{
			my $data = EPrints::Utils::clone( $_ );
			$data->{metafieldid} = $metafieldid;
			return $class->new_from_data(
				$session,
				$data,
			);
		}
	}

	return undef;
}

=item $thing = EPrints::DataObj::MetaField->new_from_data( $session, $known )

A new C<EPrints::DataObj::MetaField> object containing data $known (a hash reference).

=cut

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
	for($known,@{$known->{fields}||[]})
	{
		while(my( $name, $value ) = each %$_)
		{
			next if $name eq "sub_name"; # only field specific to sub-fields
			my $field = $dataset->get_field( $name );
			next if !$field->is_type( "boolean" ) or !defined($value);
			$_->{$name} = $RBOOLEAN{$value};
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

=item $data = EPrints::DataObj::MetaField->get_perl_struct

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
	for($data,@{$data->{fields}||[]})
	{
		while(my( $name, $value ) = each %$_)
		{
			next if $name eq "sub_name"; # only field specific to sub-fields
			my $field = $dataset->get_field( $name );
			next if !$field->is_type( "boolean" ) or !defined $value;
			$_->{$name} = $BOOLEAN{$value};
		}
	}

	# Fix for document.main (options => [])
	if( $data->{type} eq "set" && !defined $data->{options} )
	{
		$data->{options} = "";
	}

	# Split options text
	for($data,@{$data->{fields}||[]})
	{
		next if !defined $_->{options};
		$_->{options} = [split /\s*,\s*/, $_->{options}];
	}

	return $data;
}

######################################################################

=head2 Class Methods

=cut

######################################################################

######################################################################
=pod

=item $dataset = EPrints::DataObj::MetaField->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut
######################################################################

sub get_dataset_id
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
	my( $class, $session, $data ) = @_;
	
	if( $data->{name} and $data->{mfdatasetid} )
	{
		$data->{metafieldid} ||= "$data->{mfdatasetid}.$data->{name}";
	}

	$data->{"mfstatus"} = "inbox";

	$data->{"mfdatestamp"} = EPrints::Time::get_iso_timestamp();

	# This is set by DataSet for core and config fields
	$data->{"providence"} = "user";

	return $data;
}

######################################################################

=head2 Object Methods

=cut

######################################################################

sub commit
{
	my( $self, $force ) = @_;

	if( !defined $self->{changed} || scalar( keys %{$self->{changed}} ) == 0 )
	{
		# don't do anything if there isn't anything to do
		return( 1 ) unless $force;
	}

	$self->tidy;
	my $success = $self->{session}->get_database->update(
		$self->{dataset},
		$self->{data} );
	
	return( $success );
}

sub validate
{
	my( $self, $repository ) = @_;

	return [];
}

sub get_warnings
{
	my( $self ) = @_;

	return [];
}

sub get_valid_datasets
{
	qw( document eprint user saved_search import );
}

sub get_config_path
{
	my( $session ) = @_;

	return $session->get_repository->get_conf("config_path");
}

sub get_config_file
{
	my( $session ) = @_;

	return $session->get_repository->get_conf("config_path")."/cfg.d/zzz_fields.pl";
}

sub _add_config
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $datasetid = $self->get_value( "mfdatasetid" );
	my $dataset = $session->get_repository->get_dataset( $datasetid );
	my $metafieldid = $self->get_value( "metafieldid" );
	my $name = $self->get_value( "name" );

	my $file_name = get_config_file( $session );

	my $plugin = $session->plugin( "Export::Perl" );
	my $perl = "### !!!".$self->get_value( "metafieldid" )."!!! Do not edit\n" .
		$plugin->output_dataobj( $self ).",\n" .
		"### !!!".$self->get_value( "metafieldid" ) . "!!!\n\n";

	if( not -s $file_name )
	{
		open(my $fh, ">", $file_name)
			or EPrints::abort "Error writing to $file_name: $!";

		print $fh "# ".localtime(time)."\n\n";
		print $fh <<EOC;
# This file is automatically generated by the Web fields configuration
# You must leave the positional comments in place, or Web configuration will
# fail

EOC
		for(get_valid_datasets())
		{
			print $fh <<EOC;
\$c->{fields}->{$_} ||= [];
push \@{\$c->{fields}->{$_}}, (
### !!!insertion.$_!!!
);


EOC
		}

		close($fh);
	}

	open(my $fh, "<", $file_name)
		or EPrints::abort "Error reading from $file_name: $!";
	my $cfg_file = join '', <$fh>;
	close($fh);

	my $ok = $cfg_file =~ s/^### !!!insertion\.$datasetid!!!/$&\n$perl/m;

	if( $ok )
	{
		my $c;
		eval $cfg_file;
		$ok &&= $@ ? 0 : 1;
	}

	if( $ok )
	{
		open($fh, ">", $file_name)
			or EPrints::abort "Error writing to $file_name: $!";
		print $fh $cfg_file;
		close($fh);
	}

	return $ok;
}

sub _phrases_empty
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $phrases = $session->make_element( "epp:phrases" );
	$phrases->setAttribute( "xmlns", "http://www.w3.org/1999/xhtml" );
	$phrases->setAttribute( "xmlns:epp", "http://eprints.org/ep3/phrase" );
	$phrases->setAttribute( "xmlns:epc", "http://eprints.org/ep3/control" );

	my $phrase = $session->make_element( "epp:phrase",
		id=>"metapage_title_local"
	);
	$phrases->appendChild( $phrase );
	$phrase->appendChild( $session->make_text( "Misc." ) );

	return $phrases;
}

sub _opt_to_phrase
{
	my( $name ) = @_;

	$name =~ s/_/ /g;
	$name =~ s/\b(\w)/\u$1/g;

	return $name;
}

sub add_to_phrases
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $ok = 1;

	my $name = $self->get_value( "name" );
	my $datasetid = $self->get_value( "mfdatasetid" );
	my $path = get_config_path( $session ) . "/lang";

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
		my $lang_path = "$path/$langid";
		if( !-e $lang_path )
		{
			mkdir( $lang_path );
		}
		my $phrases_path = "$lang_path/phrases";
		if( !-e $lang_path )
		{
			mkdir( $phrases_path );
		}
		my $file_name = "$phrases_path/fields.xml";
		my( $doc, $xml );
		local $session->{doc};
		if( !-e $file_name )
		{
			$doc = $session->{doc} = EPrints::XML::make_document;
			$xml = $self->_phrases_empty();
			$doc->appendChild( $xml );
		}
		else
		{
			$doc = $session->{doc} = EPrints::XML::parse_xml( $file_name );
			$xml = $doc->documentElement;
		}

		while(my( $name, $text ) = each %{$phrases{$langid}})
		{
			my $phrase;
			foreach my $node ($xml->childNodes)
			{
				if( EPrints::XML::is_dom( $node, "Element" ) and
					$node->hasAttribute("id") and
					$node->getAttribute("id") eq $name )
				{
					$phrase = $node;
					last;
				}
			}
			if( defined($phrase) )
			{
				my @children = $phrase->childNodes;
				EPrints::XML::dispose($phrase->removeChild( $_ )) for @children;
			}
			else
			{
				$phrase = $session->make_element( "epp:phrase",
						id => $name
					);
				$xml->appendChild( $session->make_text( "\n\t" ) );
				$xml->appendChild( $phrase );
			}
			my $html;
			eval { $html = EPrints::XML::parse_xml_string( $text ) };
			if( $@ )
			{
				$phrase->appendChild( $session->make_text( $text ) );
			}
			else
			{
				$phrase->appendChild( $session->clone_for_me( $html->documentElement, 1 ) );
				EPrints::XML::dispose( $html );
			}
		}

		open(my $fh, ">", $file_name) or EPrints::abort "Failed to open $file_name for writing: $!";
		print $fh $doc->toString;
		close($fh);

		EPrints::XML::dispose( $doc );
	}

	return $ok;
}

sub add_to_workflow
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $ok = 1;

	my $datasetid = $self->get_value( "mfdatasetid" );
	my $path = get_config_path( $session );

	return $ok unless $datasetid eq "eprint";

	my $file_name = "$path/workflows/$datasetid/default.xml";

	return $ok unless -e $file_name;

	local $session->{doc};

	my $doc = $session->{doc} = EPrints::XML::parse_xml( $file_name );

	my $workflow = $doc->documentElement;

	my( $flow ) = $workflow->getElementsByTagName( "flow" );

	my $stage_ref;
	for($flow->childNodes)
	{
		if( EPrints::XML::is_dom( $_, "Element" ) and
			$_->hasAttribute( "ref" ) and
			$_->getAttribute( "ref" ) eq "local"
		)
		{
			$stage_ref = $_;
			last;
		}
	}
	if( !defined( $stage_ref ) )
	{
		$stage_ref = $session->make_element( "stage",
			ref => "local"
		);
		$flow->appendChild( $stage_ref );
	}

	my $stage;
	for($workflow->childNodes)
	{
		if( EPrints::XML::is_dom( $_, "Element" ) and
			$_->hasAttribute( "name" ) and
			$_->getAttribute( "name" ) eq "local"
		)
		{
			$stage = $_;
			last;
		}
	}

	if( !defined( $stage ) )
	{
		$stage = $session->make_element( "stage",
			name => "local"
		);
		$workflow->appendChild( $session->make_text( "\t" ) );
		$workflow->appendChild( $stage );
		$workflow->appendChild( $session->make_text( "\n\n" ) );
		$stage->appendChild( $session->make_text( "\n\t" ) );
	}

	my $component = $session->make_element( "component" );
	my $field = $session->make_element( "field",
		ref => $self->get_value( "name" )
	);
	$stage->appendChild( $session->make_text( "\t" ) );
	$stage->appendChild( $component );
	$stage->appendChild( $session->make_text( "\n\t" ) );
	$component->appendChild( $field );

	open(my $fh, ">", $file_name) or EPrints::abort "Failed to open $file_name for writing: $!";
	print $fh $doc->toString;
	close($fh);

	EPrints::XML::dispose( $doc );

	return $ok;
}

sub move_to_inbox
{
	my( $self ) = @_;

	$self->set_value( "mfstatus", "archive" );
	$self->commit( 1 );

	return 1;
}

sub move_to_archive
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $datasetid = $self->get_value( "mfdatasetid" );
	my $dataset = $session->get_repository->get_dataset( $datasetid );
	my $name = $self->get_value( "name" );

	$self->set_value( "mfstatus", "archive" );
	$self->commit( 1 );

	my $conf = $self->get_perl_struct;

# add to the current session
	my $fields = $session->get_repository->get_conf( "fields" );
	push @{$fields->{$datasetid}||=[]}, $conf;

# add to the dataset
	$dataset->process_field( $conf, 0 );
	my $field = $dataset->get_field( $name );

# add to the database
	$session->get_database->add_field( $dataset, $field );

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

# remove from the database
	$session->get_database->remove_field( $dataset, $field );

# remove from the dataset
	@{$dataset->{fields}} = grep { $_->{name} ne $name } @{$dataset->{fields}};

# remove from the current session
	my $fields = $session->get_repository->get_conf( "fields" );
	@{$fields->{$datasetid}} = grep { $_->{name} ne $name } @{$fields->{$datasetid}||[]};

	$self->remove();

	return 1;
}

sub get_xml_file_config
{
	my( $class, $session ) = @_;

	return $session->get_repository->get_conf( "variables_path" )."/metafield.xml";
}

sub get_perl_file_config
{
	my( $class, $session ) = @_;

	return $session->get_repository->get_conf( "variables_path" )."/metafield.pl";
}

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

sub load_all
{
	my( $session ) = @_;

	my $ds = $session->get_repository->get_dataset( "metafield" );

	my $fields = $session->get_repository->get_conf( "fields" );

	my @ids;

	foreach my $datasetid (get_valid_datasets())
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
			if( $dataobj )
			{
				$dataobj->remove if $dataobj;
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

sub remove_from_workflow
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $ok = 1;

	my $datasetid = $self->get_value( "mfdatasetid" );
	my $name = $self->get_value( "name" );
	my $path = get_config_path( $session );

	my $file_name = "$path/workflows/$datasetid/default.xml";

	return $ok unless -e $file_name;

	local $session->{doc};

	my $doc = $session->{doc} = EPrints::XML::parse_xml( $file_name );

	my $workflow = $doc->documentElement;

	my( $flow ) = $workflow->getElementsByTagName( "flow" );

	my $stage_ref;
	for($flow->childNodes)
	{
		if( EPrints::XML::is_dom( $_, "Element" ) and
			$_->hasAttribute( "ref" ) and
			$_->getAttribute( "ref" ) eq "local"
		)
		{
			$stage_ref = $_;
			last;
		}
	}
	if( !defined( $stage_ref ) )
	{
		$stage_ref = $session->make_element( "stage",
			ref => "local"
		);
		$flow->appendChild( $stage_ref );
	}

	my $stage;
	for($workflow->childNodes)
	{
		if( EPrints::XML::is_dom( $_, "Element" ) and
			$_->hasAttribute( "name" ) and
			$_->getAttribute( "name" ) eq "local"
		)
		{
			$stage = $_;
			last;
		}
	}

	if( !defined( $stage ) )
	{
		$stage = $session->make_element( "stage",
			name => "local"
		);
		$workflow->appendChild( $session->make_text( "\t" ) );
		$workflow->appendChild( $stage );
		$workflow->appendChild( $session->make_text( "\n\n" ) );
		$stage->appendChild( $session->make_text( "\n\t" ) );
	}

	my $fielde;

	foreach my $component ($stage->getElementsByTagName( "component" ))
	{
		foreach my $f ($component->getElementsByTagName( "field" ))
		{
			if( $f->getAttribute( "ref" ) eq $name )
			{
				$fielde = $f;
				last;
			}
		}
		last if $fielde;
	}

	if( $fielde )
	{
		my $component = $fielde->getParentNode;
		$component->removeChild( $fielde );
		my @fields = $component->getElementsByTagName( "field" );
		if( scalar @fields == 0 )
		{
			$stage->removeChild( $component );
		}

		open(my $fh, ">", $file_name) or EPrints::abort "Failed to open $file_name for writing: $!";
		print $fh $doc->toString;
		close($fh);
	}

	EPrints::XML::dispose( $doc );

	return $ok;
}

sub destroy_field
{
	my( $session, $dataset, $field ) = @_;

	my $file_name = get_config_file( $session );

	my $datasetid = $dataset->confid;
	my $name = $field->get_name;
	my $metafieldid = "$datasetid.$name";

	if( !-e $file_name )
	{
		return 0;
	}

	open(my $fh, "<", $file_name)
		or EPrints::abort "Error reading from $file_name: $!";
	my $cfg_file = join "", <$fh>;
	close($fh);

	my $marker = "### !!!$metafieldid!!!";
	my $ok = $cfg_file =~ s/^$marker.*?^$marker\s+//sm;

	if( $ok )
	{
		my $c;
		eval $cfg_file;
		$ok &&= $@ ? 0 : 1;
	}

	if( $ok )
	{
		open($fh, ">", $file_name)
			or EPrints::abort "Error writing to $file_name: $!";
		print $fh $cfg_file;
		close($fh);

# remove from the workflow
		_remove_workflow( $session, $dataset, $field );

# remove from the database
		$session->get_database->remove_field( $dataset, $field );

# remove from the dataset
		delete $dataset->{fields}->{$name};
		delete $dataset->{system_fields}->{$name};

# remove from the configuration
		my $fields = $session->get_repository->get_conf( "fields", $datasetid );
		@$fields = grep { $_->{name} ne $field->get_name} @$fields;

	}

	return $ok;
}

sub get_field
{
	my( $self, $session ) = @_;

	my $datasetid = $self->get_value( "mfdatasetid" );
	my $dataset = $session->get_repository->get_dataset( $datasetid );

	my $fielddata = $self->get_perl_struct();

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

1;

__END__

=back

=head1 SEE ALSO

L<EPrints::DataObj> and L<EPrints::DataSet>.

=cut

