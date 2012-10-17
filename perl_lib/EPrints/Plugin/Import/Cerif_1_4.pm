=head1 NAME

EPrints::Plugin::Import::Cerif_1_4

=cut

package EPrints::Plugin::Import::Cerif_1_4;

use EPrints::Plugin::Import::DefaultXML;
use XML::SAX::Base;

@ISA = qw( EPrints::Plugin::Import::DefaultXML XML::SAX::Base );

use strict;

our %CERIF_TYPE = (
	respubl => "eprint",
	pers => "user",
	orgunit => "org_unit",
	proj => "project",
	fund => "funding_programme",
);
our %CERIF_RELATION_TYPE = (
	respubl_respubl => ["eprint", "eprint"],
	pers_respubl => ["user", "eprint"],
	orgunit_respubl => ["org_unit", "eprint"],
	proj_respubl => ["project", "eprint"],
	proj_fund => ["project", "funding_programme"],
);
our %CERIF_CLASS_TYPE = (
	respubl_class => "eprint",
	pers_class => "user",
	persname => "user",
	pers_eaddr => "user",
);
our %CERIF_RESPUBL_TYPE = (
	book => "book",
	inbook => "book_section",
	article => "article",
	journal => "journal",
);
our %CERIF_RESPUBL_FIELD = (
	respubldate => "date",
	num => "number",
	vol => "volume",
	totalpages => "pages",
	abstr => "abstract",
);

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{name} = "CERIF 1.4";
	$self->{visible} = "all";
	$self->{produce} = [ 'list/eprint' ];

	return $self;
}

sub input_fh
{
	my( $self, %opts ) = @_;

	my $repo = $self->{session};

	local $self->{data} = {};
	local $self->{depth} = 0;
	local $self->{stack} = [];

	# mappings
	my $plugin = $self->{session}->plugin( "Export::Cerif_1_4" );
	for(qw( map_eprint_type map_eprint_ispublished ))
	{
		%{$self->{$_}} = reverse %{$plugin->param( $_ )};
	}

	eval { EPrints::XML::event_parse( $opts{fh}, $self ) };
	die $@ if $@ and "$@" ne "\n";

	$self->deconstruct();

	$self->localise();

	for(qw( eprint user ))
	{
		my $dataset = $repo->dataset( $_ );
		foreach my $epdata (values %{$self->{data}{$_} || {}})
		{
			$self->epdata_to_dataobj( $epdata,
					dataset => $dataset,
				);
		}
	}
	
	return $repo->dataset( "eprint" )->list( [] );
}

# adjust to local eprints settings
sub localise
{
	my( $self ) = @_;

	my $repo = $self->{session};

	# fix multilang
	my $dataset = $repo->dataset( "eprint" );
	for(qw( title abstract ))
	{
		next if !$dataset->has_field( $_ );
		next if $dataset->field( $_ )->isa( "EPrints::MetaField::Multilang" );
		foreach my $epdata (values %{$self->{data}{eprint} || {}})
		{
			$epdata->{$_} = $epdata->{$_}[0]{text};
		}
	}

	# remove users that are just names
	foreach my $userid (keys %{$self->{data}{user} || {}})
	{
		my $epdata = $self->{data}{user}{$userid};
		my @fieldids = grep {
				$_ !~ /^_/ &&
				$_ ne "source" &&
				EPrints::Utils::is_set( $epdata->{$_} )
			} keys %$epdata;
		if( @fieldids == 0 || (@fieldids == 1 && $fieldids[0] eq "name") )
		{
			delete $self->{data}{user}{$userid};
		}
	}

	# remove unsupported fields
	foreach my $dsid (keys %{$self->{data}})
	{
		my $dataset = $repo->dataset( $dsid );
		next if !defined $dataset;
		foreach my $epdata (values %{$self->{data}{$dsid}})
		{
			foreach my $fieldid (keys %$epdata)
			{
				delete $epdata->{$fieldid} if !$dataset->has_field( $fieldid );
			}
		}
	}
}

# sort out the mess of classes/relations
sub deconstruct
{
	my( $self ) = @_;

	my $data = $self->{data};

	# process user classes
	foreach my $class (values %{$data->{"user:class"} || {}})
	{
		my $subject = $data->{user}->{$class->{_object}};
		next if !defined $subject;
		next if !defined $class->{classid};
		if( $class->{classid} eq "email" )
		{
			$subject->{email} = $class->{eaddrid};
		}
	}
	delete $data->{"user:class"};
	
	# general tidy-up of the user data
	while(my( $objectid, $object ) = each %{$data->{user} || {}})
	{
		$object->{source} = $objectid;
		$object->{name} = {
				given => delete $object->{firstnames},
				family => delete $object->{familynames},
			};
		$object->{name}{given} .= " ".delete($object->{middlenames}) if $object->{middlenames};
	}

	# process user->* relations
	foreach my $relation (values %{$data->{"user:relation"} || {}})
	{
		my $object = $data->{user}->{$relation->{_object}};
		next if !defined $object;
		my $subject = $data->{$relation->{_subjectclass}}{$relation->{_subject}};
		next if !defined $subject;

		if( $relation->{_subjectclass} eq "eprint" && $relation->{classid} =~ /^author/ )
		{
			my $idx = @{$subject->{creators} || []};
			if( $relation->{classid} eq "author_numbered" )
			{
				# sanity check
				$idx = int($relation->{fraction} - 1)
					if $relation->{fraction} > 0 && $relation->{fraction} < 10000;
			}
			$subject->{creators}->[$idx] = {
					name => $object->{name},
					id => $object->{email},
				};
		}
	}
	delete $data->{"user:relation"};

	# process eprint classes
	foreach my $class (values %{$data->{"eprint:class"} || {}})
	{
		my $subject = $data->{eprint}->{$class->{_object}};
		next if !defined $subject;

		if( "class_scheme_publication_types" eq $class->{classschemeid} )
		{
			$subject->{type} = $self->param( "map_eprint_type" )->{lc($class->{classid})} || $class->{classid};
		}
		elsif( "class_scheme_publication_state" eq $class->{classschemeid} )
		{
			$subject->{ispublished} = $self->param( "map_eprint_ispublished" )->{lc($class->{classid})} || $class->{classid};
		}
	}
	delete $data->{"eprint:class"};
	
	# general tidy-up of the eprint data
	while(my( $objectid, $object ) = each %{$data->{eprint} || {}})
	{
		$object->{source} = $objectid;
		$object->{pagerange} = join('--', grep {
					EPrints::Utils::is_set( $_ )
				} @{$object}{qw( startpage endpage )}
			);
		$object->{keywords} = join(', ', grep {
					EPrints::Utils::is_set( $_ )
				} map {
					$_->{text}
				} @{$object->{keyw}}
			);
		for(keys %$object)
		{
			delete $object->{$_} if !EPrints::Utils::is_set( $object->{$_} );
		}
		for(qw( startpage endpage keyw ))
		{
			delete $object->{$_};
		}
	}

	# process org_unit->* relations
	foreach my $relation (values %{$data->{"org_unit:relation"} || {}})
	{
		my $object = $data->{org_unit}->{$relation->{_object}};
		next if !defined $object;
		my $subject = $data->{$relation->{_subjectclass}}{$relation->{_subject}};
		next if !defined $subject;

		no warnings; # suppress undef warnings

		if( "class_scheme_cerif_organisation_publication_roles" eq $relation->{classschemeid} )
		{
			if( "publisher_institution" eq $relation->{classid} )
			{
				$subject->{publisher} = $object->{name}[0]{text};
			}
		}
	}
	delete $data->{"org_unit:relation"};

	# process proj->* relations
	foreach my $relation (values %{$data->{"project:relation"} || {}})
	{
		my $object = $data->{project}->{$relation->{_object}};
		next if !defined $object;
		my $subject = $data->{$relation->{_subjectclass}}{$relation->{_subject}};
		next if !defined $subject;

		if( $subject->{_cf} eq "respubl" )
		{
			push @{$object->{eprint}}, $subject;
		}
		elsif( $subject->{_cf} eq "fund" )
		{
			$object->{acro} = $subject->{acro};
		}
	}

	# merge data from proj into parent eprints
	while(my( $objectid, $object ) = each %{$data->{project} || {}})
	{
		next if !EPrints::Utils::is_set( $object->{acro} );
		foreach my $eprint (@{$object->{eprint}||[]})
		{
			push @{$eprint->{funding}}, {
				funder_code => $object->{acro},
			};
		}
	}

	# process eprint->* relations
	foreach my $relation (values %{$data->{"eprint:relation"} || {}})
	{
		my $object = $data->{eprint}->{$relation->{_object}};
		next if !defined $object;
		my $subject = $data->{$relation->{_subjectclass}}{$relation->{_subject}};
		next if !defined $subject;

		no warnings; # suppress undef warnings

		if( "class_scheme_cerif_publication_publication_roles" eq $relation->{classschemeid} )
		{
			if( "part" eq $relation->{classid} )
			{
				if( "journal" eq $subject->{type} )
				{
					$object->{publication} = $subject->{title}[0]{text};
					$object->{issn} ||= $subject->{issn};
					$object->{publisher} ||= $subject->{publisher};
				}
				elsif( "book" eq $subject->{type} )
				{
					$object->{book_title} = $subject->{title}[0]{text};
					$object->{isbn} ||= $subject->{isbn};
					$object->{issn} ||= $subject->{issn};
					$object->{publisher} ||= $subject->{publisher};
				}
				else
				{
					warn "Unsupported relation: $object->{type} [$relation->{_object}] - $relation->{classid} - $subject->{type} [$relation->{_subject}]";
				}
			}
			else
			{
				warn "Unsupported classid: $relation->{classid}";
			}
		}
		else
		{
			warn "Unsupported classschemeid: $relation->{classschemeid} [$relation->{_object}]";
		}
	}
	delete $data->{"eprint:relation"};

	# clean up '_cf' typedef
	for(values %{$data->{user} || {}}, values %{$data->{eprint} || {}})
	{
		delete $_->{_cf};
	}
}

sub start_element
{
	my( $self, $data ) = @_;

	++$self->{depth};

	return if $self->{depth} == 1;

	my $name = lc($data->{LocalName}); # forgiving of our own typos as much as anything

	my( $current, $current_type );
	if( ref($self->{stack}[-1]) eq "ARRAY" )
	{
		$current = $self->{stack}[-1];
		(undef, $current_type) = split /:/, $current->[0], 2;
	}

	# entities
	if( $name =~ /^cf(respubl|pers|orgunit|proj|fund)$/ )
	{
		# object type|id|epdata
		push @{$self->{stack}}, [
				$CERIF_TYPE{$1},
				undef,
				{
					_cf => $1,
				},
			];
	}
	# relations
	elsif( $name =~ /^cf((respubl|pers|orgunit|proj)_(respubl|pers|fund))$/ )
	{
		if( !exists $CERIF_RELATION_TYPE{$1} )
		{
			push @{$self->{stack}}, undef;
			return;
		}

		my( $from, $to ) = @{$CERIF_RELATION_TYPE{$1}};
		# if there is a parent entity then we need to use its identifier as
		# either the object or subject of the relation, depending on the
		# relation type. Pers_ResPubl always has the person as the object,
		# whether the parent is a cfPers or cfResPubl
		my $side;
		if( defined $current )
		{
			$side = $2 eq $current->[2]{_cf} ? "_object" : "_subject";
		}
		push @{$self->{stack}}, [
				"$from:relation",
				APR::UUID->new->format,
				{
					(defined $side ? ($side => $current->[1]) : ()),
					_subjectclass => $to,
				},
			];
	}
	# classes
	elsif( $name =~ /^cf(respubl_class|pers_class|pers_eaddr)$/ )
	{
		my $class = $CERIF_CLASS_TYPE{$1};
		push @{$self->{stack}}, [
				"$class:class",
				APR::UUID->new->format,
				{
					_object => $current ? $current->[1] : undef,
				},
			];
	}
	# PersName (which lives in a world all by itself)
	elsif( $name =~ /^cf(persname)$/ )
	{
		if( defined $current )
		{
			push @{$self->{stack}}, $self->{stack}[-1];
		}
		else
		{
			push @{$self->{stack}}, [
					"user",
					undef,
					{},
				];
		}
	}
	# properties for entities, classes and relations
	elsif( defined $current )
	{
		# identifiers
		if( $name =~ /^cf(respublid|respublid1|respublid2|persid|orgunitid|projid|fundid)$/ )
		{
			# /CERIF/cfPers/cfPersId
			if( !defined $current->[1] )
			{
				push @{$self->{stack}},
					\($self->{stack}[-1][1] = "");
			}
			# /CERIF/cfPers_Class/cfPersId or /CERIF/cfPers_ResPubl/cfPersId
			elsif( !defined $self->{stack}[-1][2]{_object} )
			{
				push @{$self->{stack}},
					\($self->{stack}[-1][2]{_object} = "");
			}
			# /CERIF/cfPers_ResPubl/cfResPublId or /CERIF/cfPers/cfPers_ResPubl/cfResPublId
			elsif( !defined $self->{stack}[-1][2]{_subject} )
			{
				push @{$self->{stack}},
					\($self->{stack}[-1][2]{_subject} = "");
			}
			else
			{
				# both ids in the relation object, arg
				push @{$self->{stack}}, undef;
			}
		}
		# class properties
		elsif( $name =~ /^cf(classid|classschemeid|startdate|enddate|fraction)$/ )
		{
			push @{$self->{stack}},
				\($self->{stack}[-1][2]{$1} = "");
		}
		# entity properties
		elsif( $name =~ /^cf(respubldate|num|vol|edition|series|issue|startpage|endpage|totalpages|isbn|issn|birthdate|gender|familynames|middlenames|firstnames|othernames|eaddrid|acro)$/ )
		{
			my $fieldid = $CERIF_RESPUBL_FIELD{$1} || $1;
			push @{$self->{stack}}, 
				\($self->{stack}[-1][2]{$fieldid} = "");
		}
		# multilingual entity properties
		elsif( $name =~ /^cf(title|abstr|keyw|name)$/ )
		{
			my $fieldid = $CERIF_RESPUBL_FIELD{$1} || $1;
			my $langid = $data->{Attributes}{'{}cfLangCode'}{Value};
			push @{$self->{stack}[-1][2]{$fieldid}}, {
					lang => $langid,
					text => "",
				};
			push @{$self->{stack}}, \$self->{stack}[-1][2]{$fieldid}[-1]{text};
		}
		else
		{
			# Unsupported child element
			push @{$self->{stack}}, undef;
		}
	}
	else
	{
		# Unsupported element
		push @{$self->{stack}}, undef;
	}
}

sub end_element
{
	my( $self, $data ) = @_;

	--$self->{depth};

	return if $self->{depth} == 0;

	my $item = pop @{$self->{stack}};
	return if !defined $item || ref($item) ne "ARRAY";

	$self->merge_data( @$item );
}

sub merge_data
{
	my( $self, $datasetid, $objectid, $epdata ) = @_;

	return if !defined $datasetid;
	return if !defined $objectid;

	$self->{data}{$datasetid}{$objectid} = {
			%{$self->{data}{$datasetid}{$objectid} || {}},
			%$epdata,
		};
}

sub characters
{
	my( $self, $data ) = @_;

	return if ref($self->{stack}->[-1]) ne "SCALAR";

	${$self->{stack}->[-1]} .= $data->{Data};
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

