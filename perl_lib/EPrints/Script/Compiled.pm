######################################################################
#
# EPrints::Script::Compiled
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2009 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

=pod

=head1 NAME

B<EPrints::Script::Compiled> - Namespace for EPrints::Script functions.

=cut

package EPrints::Script::Compiled;

use Time::Local 'timelocal_nocheck';

sub debug
{
	my( $self, $depth ) = @_;

	$depth = $depth || 0;
	my $r = "";

	$r.= "  "x$depth;
	$r.= $self->{id};
	if( defined $self->{value} ) { $r.= " (".$self->{value}.")"; }
	if( defined $self->{pos} ) { $r.= "   #".$self->{pos}; }
	$r.= "\n";
	foreach( @{$self->{params}} )
	{
		$r.=debug( $_, $depth+1 );
	}
	return $r;
}

sub run
{
	my( $self, $state ) = @_;

	if( !defined $self->{id} ) 
	{
		$self->runtime_error( "No ID in tree node" );
	}

	if( $self->{id} eq "INTEGER" )
	{
		return [ $self->{value}, "INTEGER" ];
	}
	if( $self->{id} eq "STRING" )
	{
		return [ $self->{value}, "STRING" ];
	}

	if( $self->{id} eq "VAR" )
	{
		my $r = $state->{$self->{value}};
		if( !defined $r )
		{
			#runtime_error( "Unknown state variable ".$self->{value} );
		
			return [ 0, "BOOLEAN" ];
		}
		return $r if( ref( $r ) eq "ARRAY" );
		return [ $r ];
	}

	my @params;
	foreach my $param ( @{$self->{params}} ) 
	{ 
		my $p = $param->run( $state ); 
		push @params, $p;
	}

	my $fn = "run_".$self->{id};

        if( !defined $EPrints::Script::Compiled::{$fn} )
        {
		$self->runtime_error( "call to unknown fuction: ".$self->{id} );
                next;
        }

	no strict "refs";
	my $result = $self->$fn( $state, @params );
	use strict "refs";

	return $result;
}

sub runtime_error 
{ 
	my( $self, $msg ) = @_;

	EPrints::Script::error( $msg, $self->{in}, $self->{pos}, $self->{code} )
}

sub run_LESS_THAN
{
	my( $self, $state, $left, $right ) = @_;

	if( ref( $left->[1] ) eq "EPrints::MetaField::Date" || ref( $left->[1] ) eq "EPrints::MetaField::Time" || $left->[1] eq "DATE" )
	{
		return [ ($left->[0]||"0000") lt ($right->[0]||"0000"), "BOOLEAN" ];
	}
	
	return [ $left->[0] < $right->[0], "BOOLEAN" ];
}

sub run_GREATER_THAN
{
	my( $self, $state, $left, $right ) = @_;

	if( ref( $left->[1] ) eq "EPrints::MetaField::Date" || ref( $left->[1] ) eq "EPrints::MetaField::Time" || $left->[1] eq "DATE" )
	{
		return [ ($left->[0]||"0000") gt ($right->[0]||"0000"), "BOOLEAN" ];
	}
	
	return [ $left->[0] > $right->[0], "BOOLEAN" ];
}

sub run_EQUALS
{
	my( $self, $state, $left, $right ) = @_;

	if( $right->[1]->isa("EPrints::MetaField") && $right->[1]->{multiple} )
	{
		foreach( @{$right->[0]} )
		{
			return [ 1, "BOOLEAN" ] if( $_ eq $left->[0] );
		}
		return [ 0, "BOOLEAN" ];
	}
	
	if( $left->[1]->isa( "EPrints::MetaField") && $left->[1]->{multiple} )
	{
		foreach( @{$left->[0]} )
		{
			return [ 1, "BOOLEAN" ] if( $_ eq $right->[0] );
		}
		return [ 0, "BOOLEAN" ];
	}
	my $l = $left->[0];
	$l = "" if( !defined $l );
	my $r = $right->[0];
	$r = "" if( !defined $r );
	
	return [ $l eq $r, "BOOLEAN" ];
}

sub run_NOTEQUALS
{
	my( $self, $state, $left, $right ) = @_;

	my $r = $self->run_EQUALS( $state, $left, $right );
	
	return $self->run_NOT( $state, $r );
}

sub run_NOT
{
	my( $self, $state, $left ) = @_;

	return [ !$left->[0], "BOOLEAN" ];
}

sub run_AND
{
	my( $self, $state, $left, $right ) = @_;
	
	return [ $left->[0] && $right->[0], "BOOLEAN" ];
}

sub run_OR
{
	my( $self, $state, $left, $right ) = @_;
	
	return [ $left->[0] || $right->[0], "BOOLEAN" ];
}

sub run_PROPERTY
{
	my( $self, $state, $objvar ) = @_;

	return $self->run_property( $state, $objvar, [ $self->{value}, "STRING" ] );
}

sub run_property 
{
	my( $self, $state, $objvar, $value ) = @_;

	if( !defined $objvar->[0] )
	{
		$self->runtime_error( "can't get a property {".$value->[0]."} from undefined value" );
	}
	my $ref = ref($objvar->[0]);
	if( $ref eq "HASH" || $ref eq "EPrints::RepositoryConfig" )
	{
		my $v = $objvar->[0]->{ $value->[0] };
		my $type = ref( $v );
		$type = "STRING" if( $type eq "" ); 	
		$type = "XHTML" if( $type =~ /^XML::/ );
		return [ $v, $type ];
	}
	if( $ref !~ m/::/ )
	{
		$self->runtime_error( "can't get a property from anything except a hash or object: ".$value->[0]." (it was '$ref')." );
	}
	if( !$objvar->[0]->isa( "EPrints::DataObj" ) )
	{
		$self->runtime_error( "can't get a property from non-dataobj: ".$value->[0] );
	}
	if( !$objvar->[0]->get_dataset->has_field( $value->[0] ) )
	{
		$self->runtime_error( $objvar->[0]->get_dataset->confid . " object does not have a '".$value->[0]."' field" );
	}

	return [ 
		$objvar->[0]->get_value( $value->[0] ),
		$objvar->[0]->get_dataset->get_field( $value->[0] ),
		$objvar->[0] ];
}

sub run_MAIN_ITEM_PROPERTY
{
	my( $self, $state ) = @_;

	return run_PROPERTY( $self, $state, [$state->{item}] );
}

sub run_reverse
{
	my( $self, $state, $string ) = @_;

	return [ reverse $string->[0], "STRING" ];
} 
	
sub run_is_set
{
	my( $self, $state, $param ) = @_;

	return [ EPrints::Utils::is_set( $param->[0] ), "BOOLEAN" ];
} 

sub run_citation_link
{
	my( $self, $state, $object, $citationid ) = @_;

	my $citation = $object->[0]->render_citation_link( $citationid->[0]  );

	return [ $citation, "XHTML" ];
}

sub run_citation
{
	my( $self, $state, $object, $citationid ) = @_;

	my $stylespec = $state->{session}->get_citation_spec( $object->[0]->get_dataset, $citationid->[0] );

	my $citation = EPrints::XML::EPC::process( $stylespec, item=>$object->[0], session=>$state->{session}, in=>"Citation:".$object->[0]->get_dataset.".".$citationid->[0] );

	return [ $citation, "XHTML" ];
}

sub run_yesno
{
	my( $self, $state, $left ) = @_;

	if( $left->[0] )
	{
		return [ "yes", "STRING" ];
	}

	return [ "no", "STRING" ];
}

sub run_one_of
{
	my( $self, $state, $left, @list ) = @_;

	if( !defined $left )
	{
		return [ 0, "BOOLEAN" ];
	}
	if( !defined $left->[0] )
	{
		return [ 0, "BOOLEAN" ];
	}

	foreach( @list )
	{
		my $result = $self->run_EQUALS( $state, $left, $_ );
		return [ 1, "BOOLEAN" ] if( $result->[0] );
	}
	return [ 0, "BOOLEAN" ];
} 

sub run_as_item 
{
	my( $self, $state, $itemref ) = @_;

	if( !$itemref->[1]->isa( "EPrints::MetaField::Itemref" ) )
	{
		$self->runtime_error( "can't call as_item on anything but a value of type itemref" );
	}

	my $object = $itemref->[1]->get_item( $state->{session}, $itemref->[0] );

	return [ $object ];
}

sub run_as_string
{
	my( $self, $state, $value ) = @_;

	return [ $value->[0], "STRING" ];
}

sub run_strlen
{
	my( $self, $state, $value ) = @_;

	if( !EPrints::Utils::is_set( $value->[0] ) )
	{
		return [0,"INTEGER"];
	}

	return [ length( $value->[0] ), "INTEGER" ];
}

sub run_length
{
	my( $self, $state, $value ) = @_;

	if( !EPrints::Utils::is_set( $value->[0] ) )
	{
		return [0,"INTEGER"];
	}
	
	if( !$value->[1]->isa( "EPrints::MetaField" ) )
	{
		return [1,"INTEGER"];
	}

	if( !$value->[1]->get_property( "multiple" ) ) 
	{
		return [1,"INTEGER"];
	}

	return [ scalar @{$value->[0]}, "INTEGER" ];
}

sub run_today
{
	my( $self, $state ) = @_;

	return [EPrints::Time::get_iso_date, "DATE"];
}

sub run_datemath
{
	my( $self, $state, $date, $alter, $type ) = @_;

	my( $year, $month, $day ) = split( "-", $date->[0] );

	if( $type->[0] eq "day" )
	{
		$day+=$alter->[0];
	}
	elsif( $type->[0] eq "month" )
	{
		$month+=$alter->[0];
		while( $month < 1 )
		{
			$year--;
			$month += 12;
		}
		while( $month > 12 )
		{
			$year++;
			$month -= 12;
		}
		
	}
	elsif( $type->[0] eq "year" )
	{
		$year+=$alter->[0];
	}
	else
	{
		return [ "DATE ERROR: Unknown part '".$type->[0]."'", "STRING" ];
	}

        my $t = timelocal_nocheck( 0,0,0,$day,$month-1,$year-1900 );

	return [ EPrints::Time::get_iso_date( $t ), "DATE" ];
}

sub run_dataset 
{
	my( $self, $state, $object ) = @_;

	if( !$object->[0]->isa( "EPrints::DataObj" ) )
	{
		$self->runtime_error( "can't call dataset on non-data objects." );
	}

	return [ $object->[0]->get_dataset->confid, "STRING" ];
}

sub run_related_objects
{
	my( $self, $state, $object, @required ) = @_;

	if( !defined $object->[0] || ref($object->[0])!~m/^EPrints::DataObj::/ )
	{
		$self->runtime_error( "can't call dataset on non-data objects." );
	}

	my @r = ();
	foreach( @required ) { push @r, $_->[0]; }
	
	return [ $object->[0]->get_related_objects( @r ) ];
}

sub run_url
{
	my( $self, $state, $object ) = @_;

	if( !defined $object->[0] || ref($object->[0])!~m/^EPrints::DataObj::/ )
	{
		$self->runtime_error( "can't call url() on non-data objects." );
	}

	return [ $object->[0]->get_url, "STRING" ];
}

sub run_doc_size
{
	my( $self, $state, $doc ) = @_;

	if( !defined $doc->[0] || ref($doc->[0]) ne "EPrints::DataObj::Document" )
	{
		$self->runtime_error( "Can only call document_size() on document objects not ".
			ref($doc->[0]) );
	}

	my %files = $doc->[0]->files;

	return $files{$doc->[0]->get_main} || 0;
}

sub run_is_public
{
	my( $self, $state, $doc ) = @_;

	if( !defined $doc->[0] || ref($doc->[0]) ne "EPrints::DataObj::Document" )
	{
		$self->runtime_error( "Can only call document_size() on document objects not ".
			ref($doc->[0]) );
	}

	return [ $doc->[0]->is_public, "BOOLEAN" ];
}

sub run_thumbnail_url
{
	my( $self, $state, $doc, $size ) = @_;

	if( !defined $doc->[0] || ref($doc->[0]) ne "EPrints::DataObj::Document" )
	{
		$self->runtime_error( "Can only call thumbnail_url() on document objects not ".
			ref($doc->[0]) );
	}

	return [ $doc->[0]->thumbnail_url( $size->[0] ), "STRING" ];
}

sub run_preview_link
{
	my( $self, $state, $doc, $caption, $set ) = @_;

	if( !defined $doc->[0] || ref($doc->[0]) ne "EPrints::DataObj::Document" )
	{
		$self->runtime_error( "Can only call thumbnail_url() on document objects not ".
			ref($doc->[0]) );
	}

	return [ $doc->[0]->render_preview_link( caption=>$caption->[0], set=>$set->[0] ), "XHTML" ];
}

sub run_icon
{
	my( $self, $state, $doc, $preview, $new_window ) = @_;

	if( !defined $doc->[0] || ref($doc->[0]) ne "EPrints::DataObj::Document" )
	{
		$self->runtime_error( "Can only call thumbnail_url() on document objects not ".
			ref($doc->[0]) );
	}

	return [ $doc->[0]->render_icon_link( preview=>$preview->[0], new_window=>$new_window->[0] ), "XHTML" ];
}


sub run_human_filesize
{
	my( $self, $state, $size_in_bytes ) = @_;

	return [ EPrints::Utils::human_filesize( $size_in_bytes || 0 ), "INTEGER" ];
}

sub run_control_url
{
	my( $self, $state, $eprint ) = @_;

	if( !defined $eprint->[0] || ref($eprint->[0]) ne "EPrints::DataObj::EPrint" )
	{
		$self->runtime_error( "Can only call control_url() on eprint objects not ".
			ref($eprint->[0]) );
	}

	return [ $eprint->[0]->get_control_url(), "STRING" ];
}

sub run_contact_email
{
	my( $self, $state, $eprint ) = @_;

	if( !defined $eprint->[0] || ref($eprint->[0]) ne "EPrints::DataObj::EPrint" )
	{
		$self->runtime_error( "Can only call contact_email() on eprint objects not ".
			ref($eprint->[0]) );
	}

	if( !$state->{session}->get_repository->can_call( "email_for_doc_request" ) )
	{
		return [ undef, "STRING" ];
	}

	return [ $state->{session}->get_repository->call( "email_for_doc_request", $state->{session}, $eprint->[0] ), "STRING" ]; 
}

sub run_uri
{
	my( $self, $state, $dataobj ) = @_;

	return [ $dataobj->[0]->uri, "STRING" ];
}

# item is optional and it's primary key is passed to the list rendering bobbles
# for actions which need a current object.
sub run_action_list
{
	my( $self, $state, $list_id, $item ) = @_;

	my $screen_processor = EPrints::ScreenProcessor->new(
		session => $state->{session},
		screenid => "FirstTool",
	);

	my $screen = $screen_processor->screen;
	$screen->properties_from;

	my @list = $screen->list_items( $list_id->[0], filter=>0 );
	if( defined $item )
	{
        	my $keyfield = $item->[0]->{dataset}->get_key_field();
		$screen_processor->{$keyfield->get_name()} = $item->[0]->get_id;
		foreach my $action ( @list )
		{
			$action->{hidden} = [$keyfield->get_name()];
		}
	}

	return [ \@list, "ARRAY" ];
}

sub run_action_button
{
	my( $self, $state, $action_p ) = @_;

	my $action = $action_p->[0]; 
	
	return [ $action->{screen}->render_action_button( $action ), "XHTML" ];
}
sub run_action_icon
{
	my( $self, $state, $action_p ) = @_;

	my $action = $action_p->[0]; 
	
	return [ $action->{screen}->render_action_icon( $action ), "XHTML" ];
}
sub run_action_description
{
	my( $self, $state, $action_p ) = @_;

	my $action = $action_p->[0]; 
	
	return [ $action->{screen}->get_description( $action ), "XHTML" ];
}

sub run_action_title
{
	my( $self, $state, $action_p ) = @_;

	my $action = $action_p->[0]; 
	
	if( defined $action->{action} )
	{
		return [ $action->{screen}->html_phrase( "action:".$action->{action}.":title" ), "XHTML" ];
	}
	else
	{
		return [ $action->{screen}->html_phrase( "title" ), "XHTML" ];
	}
}

1;
