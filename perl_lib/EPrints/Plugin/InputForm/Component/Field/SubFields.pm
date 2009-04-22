package EPrints::Plugin::InputForm::Component::Field::SubFields;

use EPrints::Plugin::InputForm::Component::Field;
@ISA = ( "EPrints::Plugin::InputForm::Component::Field" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );
	
	$self->{name} = "Subfields Selector";
	$self->{visible} = "all";
	$self->{visdepth} = 1;
	return $self;
}

sub update_from_form
{
	my( $self, $processor ) = @_;

	my $session = $self->{session};
	my $field = $self->{config}->{field};
	my $metafield = $self->{dataobj};
	my $mfdatasetid = $metafield->get_value( "mfdatasetid" );
	my $dataset = $session->get_repository->get_dataset( $mfdatasetid );
	my $prefix = quotemeta( $metafield->get_value( "name" ) . "_" );

	my @fieldids = $session->param( $self->{prefix} );

	my $value = $metafield->get_value( $field->get_name );
	my @value = @$value;

	my %checked = map { $_ => 1 } @fieldids;

	# enable/disable existing entries
	foreach my $fielddata (@value)
	{
		my $name = $metafield->get_value( "name" )."_".$fielddata->{sub_name};
		$fielddata->{mfremoved} = $checked{$name} ? "FALSE" : "TRUE";
		delete $checked{$name};
	}

	my $potential = $self->get_potential_metafields;

	# add any new entries
	foreach my $fieldid (keys %checked)
	{
		my $sub_name = $fieldid;
		next unless $sub_name =~ s/^$prefix//;

		my $fielddata = $potential->{$sub_name};
		next unless defined $fielddata;

		$fielddata->{mfremoved} = "FALSE";

		push @value, $fielddata;
	}

	$metafield->set_value( $field->{name}, \@value );
}

sub render_content
{
	my( $self, $surround ) = @_;

	my $session = $self->{session};
	my $field = $self->{config}->{field};
	my $metafield = $self->{dataobj};

	my $value = $metafield->get_value( $field->get_name );
	my @value = @$value;

	my $out = $session->make_element( "div" );

	my $dataset = $session->get_repository->get_dataset( $metafield->get_value( "mfdatasetid" ) );

	my $prefix = $metafield->get_value( "name" ) . "_";

	my $potential = $self->get_potential_metafields;
	foreach my $sub_name (keys %$potential)
	{
		my $is_new = 1;
		for(@$value)
		{
			$is_new = 0, last if $_->{sub_name} eq $sub_name;
		}
		next unless $is_new;

		my $fielddata = $potential->{$sub_name};

		push @value, $fielddata;
	}

	foreach my $fielddata (sort { $a->{sub_name} cmp $b->{sub_name} } @value)
	{
		my $name = $prefix . $fielddata->{"sub_name"};
		my $selected = defined($fielddata->{mfremoved}) && $fielddata->{mfremoved} eq "FALSE";
		my $option = $session->render_input_field(
			type => "checkbox",
			name => $self->{prefix},
			value => $name,
			($selected ? (checked => "checked") : ()),
		);
		$option->appendChild( $session->make_text( $name ) );
		$out->appendChild( $option );
		$out->appendChild( $session->make_element( "br" ) );
	}

	return $out;
}

sub get_potential_metafields
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $field = $self->{config}->{field};
	my $metafield = $self->{dataobj};
	my $prefix = $metafield->get_value( "name" ) . "_";

	my $dataset = $metafield->get_dataset;

	my $searchexp = EPrints::Search->new(
		session => $session,
		dataset => $dataset,
		filters => [
			{ meta_fields => ["providence"], match => "EQ", value => "user" },
			{ meta_fields => ["mfdatasetid"], match => "EQ", value => $metafield->get_value( "mfdatasetid" ) },
		]);

	my $list = $searchexp->perform_search;

	my %potential;
	$list->map( sub {
		my( undef, undef, $mf ) = @_;

		my $name = $mf->get_value( "name" );
		return unless $name =~ /^$prefix/;

		my $field = $mf->make_field_object;
		return unless defined $field;
		return if $field->isa( "EPrints::MetaField::Compound" );

		my $fielddata = $mf->get_perl_struct;

		$fielddata->{sub_name} = delete $fielddata->{name};
		$fielddata->{sub_name} =~ s/^$prefix//;

		$potential{$fielddata->{sub_name}} = $fielddata;
	} );

	$list->dispose;

	return \%potential;
}

1;
