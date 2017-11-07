######################################################################
#
# EPrints::DataObj::History
#
######################################################################
#
#
######################################################################


=pod

=head1 NAME

B<EPrints::DataObj::History> - An element in the history of the arcvhive.

=head1 DESCRIPTION

This class describes a single item in the history dataset. A history
object describes a single action taken on a single item in another
dataset.

Changes to document are considered part of changes to the eprint it
belongs to.

=head1 METADATA

=over 4

=item historyid (int)

The unique numerical ID of this history event. 

=item userid (itemref)

The id of the user who caused this event. A value of zero or undefined
indicates that there was no user responsible (ie. a script did it). 

=item datasetid (text)

The name of the dataset to which the modified item belongs. "eprint"
is used for eprints, rather than the inbox, buffer etc.

=item objectid (int)

The numerical ID of the object in the dataset. 

=item revision (int)

The revision of the object. This is the revision number after the
action occurred. Not all actions increase the revision number.

=item timestamp (time)

The moment at which this thing happened.

=item action (set)

The type of event. Provisionally, this is a subset of the new list
of privilages.

=item details (longtext)

If this is a "rejection" then the details contain the message sent
to the user. 

=back

=head1 METHODS

=over 4

=cut

package EPrints::DataObj::History;

@ISA = ( 'EPrints::DataObj::SubObject' );

use EPrints;

use strict;

# Override this with 'max_history_width' in a configuration file
our $DEFAULT_MAX_WIDTH = 120;

######################################################################
=pod

=item $field_info = EPrints::DataObj::History->get_system_field_info

Return the metadata field configuration for this object.

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"historyid", type=>"counter", required=>1, can_clone=>0,
			sql_counter=>"historyid" }, 

		{ name=>"userid", type=>"itemref", 
			datasetid=>"user", required=>0 },

		{ name=>"actor", type=>"text", text_index=>0, },
	
		# should maybe be a set?
		{ name=>"datasetid", type=>"id", text_index=>0, }, 

		# is this required?
		{ name=>"objectid", type=>"int", }, 

		{ name=>"revision", type=>"int", },

		{ name=>"timestamp", type=>"timestamp", }, 

		# TODO should be a set when I know what the actions will be
		{ name=>"action", type=>"set", text_index=>0, options=>[qw/
				create 
				modify 
				mail_owner 
				move_inbox_to_buffer 
				move_buffer_to_archive 
				move_buffer_to_inbox 
				move_archive_to_deletion 
				move_archive_to_buffer 
				move_deletion_to_archive
				destroy
				removal_request 
				reject_request
				accept_request
				note
				other
				/], },

		{ name=>"details", type=>"longtext", text_index=>0, 
render_single_value => \&EPrints::Extras::render_preformatted_field }, 
	);
}



######################################################################
=pod

=item $dataset = EPrints::DataObj::History->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut
######################################################################

sub get_dataset_id
{
	return "history";
}



######################################################################
=pod

=item $history->commit 

Not meaningful. History can't be altered.

=cut
######################################################################

sub commit 
{
	my( $self, $force ) = @_;

	$self->{session}->get_repository->log(
		"WARNING: Called commit on a EPrints::DataObj::History object." );

	return 0;
}


######################################################################
=pod

=item $history->remove

Not meaningful. History can't be altered.

=cut
######################################################################

sub remove
{
	my( $self ) = @_;
	
	$self->{session}->get_repository->log(
		"WARNING: Called remove on a EPrints::DataObj::History object." );
	return 0;
}

######################################################################
# =pod
# 
# =item EPrints::DataObj::History::create( $session, $data );
# 
# Create a new history object from this data. Unlike other create
# methods this one does not return the new object as it's never 
# needed, and would increase the load of modifying items.
# 
# Also, this does not queue the fields for indexing.
# 
# =cut
######################################################################

sub create
{
	my( $session, $data ) = @_;

	return EPrints::DataObj::History->create_from_data( 
		$session, 
		$data,
		$session->dataset( "history" ) );
}

######################################################################
=pod

=item $defaults = EPrints::DataObj::History->get_defaults( $session, $data )

Return default values for this object based on the starting data.

=cut
######################################################################

sub get_defaults
{
	my( $class, $session, $data, $dataset ) = @_;
	
	$class->SUPER::get_defaults( $session, $data, $dataset );

	my $user;
	if( defined $data->{userid} )
	{
		$user = EPrints::DataObj::User->new( $session, $data->{userid} );
	}
	if( defined $user ) 
	{
		$data->{actor} = EPrints::Utils::tree_to_utf8( $user->render_description() );
	}
	else
	{
		# command line or not logged in. Store script name.
		$data->{actor} = $0;
	}

	return $data;
}

######################################################################
#
# $xhtml = $history->render_citation( $style, $url )
#
# This overrides the normal citation rendering and just does a full
# render of the event.
#
######################################################################

sub render_citation
{
	my( $self , $style , $url ) = @_;

	return $self->render;
}

######################################################################
=pod

=item $xhtml = $history->render

Render this change as XHTML DOM.

=cut
######################################################################

sub render
{
	my( $self ) = @_;

	my %pins = ();
	
	my $user = $self->get_user;
	if( defined $user )
	{
		$pins{cause} = $user->render_description;
	}
	else
	{
		$pins{cause} = $self->{session}->make_element( "code" );
		$pins{cause}->appendChild( $self->{session}->make_text( $self->get_value( "actor" ) ) );
	}

	$pins{when} = $self->render_value( "timestamp" );

	my $action = $self->get_value( "action" );

	$pins{action} = $self->render_value( "action" );

	if( $action eq "modify" ) { $pins{details} = $self->render_modify; }
	elsif( $action =~ m/^move_/ ) { $pins{details} = $self->{session}->render_nbsp; } # no details
	elsif( $action eq "destroy" ) { $pins{details} = $self->{session}->render_nbsp; } # no details
	elsif( $action eq "create" ) { $pins{details} = $self->render_create; }
	elsif( $action eq "mail_owner" ) { $pins{details} = $self->render_with_details; }
	elsif( $action eq "note" ) { $pins{details} = $self->render_with_details; }
	elsif( $action eq "other" ) { $pins{details} = $self->render_with_details; }
	elsif( $action eq "removal_request" ) { $pins{details} = $self->render_removal_request; }
	else { $pins{details} = $self->{session}->make_text( "Don't know how to render history event: $action" ); }

	my $obj  = $self->get_dataobj;
	if( defined $obj )
	{
		$pins{item} = $self->{session}->make_doc_fragment;
		$pins{item}->appendChild( $obj->render_description );
		$pins{item}->appendChild( $self->{session}->make_text( " (" ) );
 		my $a = $self->{session}->render_link( $obj->get_control_url );
		$pins{item}->appendChild( $a );
		$a->appendChild( $self->{session}->make_text( $self->get_value( "datasetid" )." ".$self->get_value("objectid" ) ) );
		$pins{item}->appendChild( $self->{session}->make_text( " r".$self->get_value( "revision" ) ) );
		$pins{item}->appendChild( $self->{session}->make_text( ")" ) );
	}
	else
	{
		$pins{item} = $self->{session}->html_phrase( 
			"lib/history:no_such_item", 
			datasetid=>$self->{session}->make_text($self->get_value( "datasetid" ) ),
			objectid=>$self->{session}->make_text($self->get_value( "objectid" ) ),
			 );
	}
		
	#$pins{item}->appendChild( $self->render_value( "historyid" ));
	
	return $self->{session}->html_phrase( "lib/history:record", %pins );
}

######################################################################
=pod

=item $object = $history->get_dataobj

Returns the object to which this history event relates.

=cut
######################################################################

sub get_dataobj
{
	my( $self ) = @_;

	return unless( $self->is_set( "datasetid" ) );
	my $ds = $self->{session}->get_repository->get_dataset( $self->get_value( "datasetid" ) );
	return $ds->get_object( $self->{session}, $self->get_value( "objectid" ) );
}

######################################################################
=pod

=item $user = $history->get_user

Returns the user object of the user who caused this event.

=cut
######################################################################

sub get_user
{
	my( $self ) = @_;

	return undef unless $self->is_set( "userid" );

	if( defined($self->{user}) )
	{
		# check we still have the same owner
		if( $self->{user}->get_id eq $self->get_value( "userid" ) )
		{
			return $self->{user};
		}
	}

	$self->{user} = EPrints::DataObj::User->new( 
		$self->{session}, 
		$self->get_value( "userid" ) );

	return $self->{user};
}

=item $history = $history->get_previous()

Returns the previous event for the object parent of this event.

Returns undef if no such event exists.

=cut

sub get_previous
{
	my( $self ) = @_;

	return $self->{_previous} if exists( $self->{_previous} );

	my $dataset = $self->get_dataset;

	my $revision = $self->get_value( "revision" ) - 1;
	
	my $results = $dataset->search(
		filters => [
			{
				meta_fields => [ "datasetid" ],
				value => $self->value( "datasetid" ),
			},
			{
				meta_fields => [ "objectid" ],
				value => $self->value( "objectid" ),
			},
			{
				meta_fields => [ "revision" ],
				value => $revision,
			}
		]);

	return $self->{_previous} = $results->item( 0 );
}

######################################################################
#
# methods to render various types of history event
#
######################################################################



######################################################################
#
# $xhtml = $history->render_removal_request
#
# Render a removal request history event. 
#
######################################################################

sub render_removal_request
{
	my( $self ) = @_;

	my $div = $self->{session}->make_element( "div" );
	$div->appendChild( $self->render_value("details") );
	return $div;
}

######################################################################
#
# $xhtml = $history->render_with_details
#
# Render a MAIL_OWNER history event. 
#
######################################################################

sub render_with_details
{
	my( $self ) = @_;

	my $div = $self->{session}->make_element( "div" );
	$div->appendChild( $self->render_value("details") );
	return $div;
}

######################################################################
#
# $xhtml = $history->render_create( $action )
#
# Render a CREATE history event. 
#
######################################################################

sub render_create
{
	my( $self ) = @_;

	my $width = $self->{session}->get_repository->get_conf( "max_history_width" ) || $DEFAULT_MAX_WIDTH;

	my $r_file = $self->get_stored_file( "dataobj.xml" );
	my $r_file_new;
	if( !defined( $r_file ) || !defined($r_file_new = $r_file->get_local_copy) )
	{
		my $div = $self->{session}->make_element( "div" );
		$div->appendChild( $self->{session}->html_phrase( "lib/history:no_file" ) );
		return $div;
	}

	my $file_new = EPrints::XML::parse_xml( "$r_file_new" );
	my $dom_new = $file_new->getFirstChild;

	my $div = $self->{session}->make_element( "div" );
	$div->appendChild( $self->{session}->html_phrase( "lib/history:xmlblock", xml=>render_xml( $self->{session}, $dom_new, 0, 0, $width ) ) );

	return $div;
}

######################################################################
#
# $xhtml = $history->render_modify( $action )
#
# Render a MODIFY history event. 
#
######################################################################

sub render_modify
{
	my( $self ) = @_;

	my $width = $self->{session}->get_repository->get_conf( "max_history_width" ) || $DEFAULT_MAX_WIDTH;

	my $r_file = $self->get_stored_file( "dataobj.xml" );
	my $r_file_new = defined($r_file) ? $r_file->get_local_copy() : undef;

	if( !defined $r_file || !defined $r_file_new )
	{
		my $div = $self->{session}->make_element( "div" );
		$div->appendChild( $self->{session}->html_phrase( "lib/history:no_file" ) );
		return $div;
	}

	my $file_new = EPrints::XML::parse_xml( "$r_file_new" );
	my $dom_new = $file_new->getFirstChild;

	$r_file = undef;

	my $previous = $self->get_previous();
	if( defined( $previous ) )
	{
		$r_file = $previous->get_stored_file( "dataobj.xml" );
	}

	unless( defined( $r_file ) )
	{
		my $div = $self->{session}->make_element( "div" );
		$div->appendChild( $self->{session}->html_phrase( "lib/history:no_earlier" ) );
		$div->appendChild( $self->{session}->html_phrase( "lib/history:xmlblock", xml=>render_xml( $self->{session}, $dom_new, 0, 0, $width ) ) );
		return $div;
	}

	my $r_file_old = $r_file->get_local_copy();
	if( !defined $r_file_old )
	{
		return $self->render_create;
	}

	my $file_old = EPrints::XML::parse_xml( "$r_file_old" );
	my $dom_old = $file_old->getFirstChild;

	my %fieldnames = ();

	my %old_nodes = ();
	foreach my $cnode ( $file_old->getFirstChild->getChildNodes )
	{
		next unless EPrints::XML::is_dom( $cnode, "Element" );
		$fieldnames{$cnode->nodeName}=1;
		$old_nodes{$cnode->nodeName}=$cnode;
	}

	my %new_nodes = ();
	foreach my $cnode ( $file_new->getFirstChild->getChildNodes )
	{
		next unless EPrints::XML::is_dom( $cnode, "Element" );
		$fieldnames{$cnode->nodeName}=1;
		$new_nodes{$cnode->nodeName}=$cnode;
	}

	my $table;
	my $tr;
	my $td;
	$table = $self->{session}->make_element( "table" , width=>"100%", cellspacing=>"0", cellpadding=>"0");
	$tr = $self->{session}->make_element( "tr" );
	$td = $self->{session}->make_element( "td", valign=>"top", width=>"50%" );
	$td->appendChild( $self->{session}->html_phrase( "lib/history:before" ) );
	$tr->appendChild( $td );
	$td = $self->{session}->make_element( "td", valign=>"top", width=>"50%" );
	$td->appendChild( $self->{session}->html_phrase( "lib/history:after" ) );
	$tr->appendChild( $td );
	$table->appendChild( $tr );

	foreach my $fn ( keys %fieldnames )
	{
		if( !empty_tree( $old_nodes{$fn} ) && empty_tree( $new_nodes{$fn} ) )
		{
			my( $old, $pad ) = render_xml( $self->{session}, $old_nodes{$fn}, 0, 1, int($width/2)-1 );
			$tr = $self->{session}->make_element( "tr" );

			$td = $self->{session}->make_element( "td", valign=>"top", width=>"50%", style=>"background-color: #fcc; " );
			$td->appendChild( $self->{session}->html_phrase( "lib/history:xmlblock", xml=>$old ) );
			$tr->appendChild( $td );

			$td = $self->{session}->make_element( "td", valign=>"top", width=>"50%" );
			my $f = $self->{session}->make_doc_fragment;			
			$f->appendChild( $self->{session}->render_nbsp );
			$f->appendChild( $pad );
			$td->appendChild( $self->{session}->html_phrase( "lib/history:xmlblock", xml=>$f ) );
			$tr->appendChild( $td );

			$table->appendChild( $tr );
		}
		elsif( empty_tree( $old_nodes{$fn} ) && !empty_tree( $new_nodes{$fn} ) )
		{
			my( $new, $pad ) = render_xml( $self->{session}, $new_nodes{$fn}, 0, 1, int($width/2)-1 );
			$tr = $self->{session}->make_element( "tr" );
			$td = $self->{session}->make_element( "td", valign=>"top", width=>"50%" );

			my $f = $self->{session}->make_doc_fragment;			
			$f->appendChild( $self->{session}->render_nbsp );
			$f->appendChild( $pad );
			$td->appendChild( $self->{session}->html_phrase( "lib/history:xmlblock", xml=>$f ) );
			$tr->appendChild( $td );

			$td = $self->{session}->make_element( "td", valign=>"top", width=>"50%", style=>"background-color: #cfc" );
			$td->appendChild( $self->{session}->html_phrase( "lib/history:xmlblock", xml=>$new ) );
			$tr->appendChild( $td );

			$table->appendChild( $tr );
		}
		elsif( diff( $old_nodes{$fn}, $new_nodes{$fn} ) )
		{
			$tr = $self->{session}->make_element( "tr" );
			my( $t1, $t2 ) = render_xml_diffs( $self->{session}, $old_nodes{$fn}, $new_nodes{$fn}, 0, int($width/2)-1 );

			$td = $self->{session}->make_element( "td", valign=>"top", width=>"50%", style=>"background-color: #ffc" );
			$td->appendChild( $self->{session}->html_phrase( "lib/history:xmlblock", xml=>$t1 ) );
			$tr->appendChild( $td );

			$td = $self->{session}->make_element( "td", valign=>"top", width=>"50%", style=>"background-color: #ffc" );
			$td->appendChild( $self->{session}->html_phrase( "lib/history:xmlblock", xml=>$t2 ) );
			$tr->appendChild( $td );

			$table->appendChild( $tr );
		}
	}

	return $table;
}



######################################################################
#
# $boolean = EPrints::DataObj::History::empty_tree( $domtree )
#
# return true if there is no text in the tree other than
# whitespace,
#
# Will maybe be moved to XML or Utils
#
######################################################################

sub empty_tree
{
	my( $domtree ) = @_;

	return 1 unless defined $domtree;

	if( EPrints::XML::is_dom( $domtree, "Text" ) )
	{
		my $v = $domtree->nodeValue;
		
		if( $v=~m/^[\s\r\n]*$/ )
		{
			return 1;
		}
		return 0;
	}

	if( EPrints::XML::is_dom( $domtree, "Element" ) )
	{
		foreach my $cnode ( $domtree->getChildNodes )
		{
			unless( empty_tree( $cnode ) )
			{
				return 0;
			}
		}
		return 1;
	}

	return 1;
}

######################################################################
#
# $xhtml = EPrints::DataObj::History::render_xml_diffs( $tree1, $tree2, $indent, $width )
#
# Render the diffs between tree1 and tree2 as XHTML
#
######################################################################

sub render_xml_diffs
{
	my( $session, $tree1, $tree2, $indent, $width ) = @_;

	if( EPrints::XML::is_dom( $tree1, "Text" ) && EPrints::XML::is_dom( $tree2, "Text" ))
	{
		my $v1 = $tree1->nodeValue;
		my $v2 = $tree2->nodeValue;
		$v1=~s/^[\s\r\n]*$//;
		$v2=~s/^[\s\r\n]*$//;
		if( $v1 eq "" && $v2 eq "" )
		{
			return( $session->make_doc_fragment, $session->make_doc_fragment );
		}
		#return $session->make_text( ("  "x$indent).$v."\n" );
		return( $session->make_text( ("  "x$indent).$v1."\n" ), $session->make_text( ("  "x$indent).$v2."\n" ) );
	}

	unless( EPrints::XML::is_dom( $tree1, "Element" ) && EPrints::XML::is_dom( $tree2, "Element" ))
	{
		return(
			$session->make_text( "schema changed?:".ref($tree1) ),
			$session->make_text( "schema changed?:".ref($tree2) )
			);
	}

	my $f1 = $session->make_doc_fragment;
	my $f2 = $session->make_doc_fragment;
	my $name1 = $tree1->nodeName;
	my $name2 = $tree2->nodeName;
	my( @list1 ) = $tree1->getChildNodes;
	my( @list2 ) = $tree2->getChildNodes;
	my $justtext = 1;
	my $t1 = "";
	my $t2 = "";
	foreach my $cnode ( @list1 )
	{
		unless( EPrints::XML::is_dom( $cnode,"Text" ) )
		{	
			$justtext = 0;
			last;
		}
		$t1.=$cnode->nodeValue;
	}
	foreach my $cnode ( @list2 )
	{
		unless( EPrints::XML::is_dom( $cnode,"Text" ) )
		{	
			$justtext = 0;
			last;
		}
		$t2.=$cnode->nodeValue;
	}

	if( $justtext )
	{
		$f1->appendChild( $session->make_text( "  "x$indent ) );
		$f1->appendChild( $session->make_text( "<$name1>" ) );
		$f2->appendChild( $session->make_text( "  "x$indent ) );
		$f2->appendChild( $session->make_text( "<$name2>" ) );
		my $offset = $indent*2+length($name1)+2;
		my $endw = length($name1)+3;
		my $s1;
		my $s2;
		if( $t1 eq $t2 )
		{
			$s1 = $session->make_element( "span", style=>"" );
			$s1->appendChild( mktext( $session, $t1, $offset, $endw, $width ) );
			$s2 = $session->make_element( "span", style=>"" );
			$s2->appendChild( mktext( $session, $t2, $offset, $endw, $width ) );
		}
		elsif( $t1 eq "" )
		{
			$s1 = $session->make_element( "span", style=>"" );
			$s1->appendChild( mkpad( $session, $t2, $offset, $endw, $width ) );
			$s2 = $session->make_element( "span", style=>"background: #cfc;" );
			$s2->appendChild( mktext( $session, $t2, $offset, $endw, $width ) );
		}
		elsif( $t2 eq "" )
		{
			$s1 = $session->make_element( "span", style=>"background: #fcc" );
			$s1->appendChild( mktext( $session, $t1, $offset, $endw, $width ) );
			$s2 = $session->make_element( "span", style=>"" );
			$s2->appendChild( mkpad( $session, $t1, $offset, $endw, $width ) );
		}
		else
		{
			my $h1 = scalar _mktext( $session, $t1, $offset, $endw, $width );
			my $h2 = scalar _mktext( $session, $t2, $offset, $endw, $width );
			$s1 = $session->make_element( "span", style=>"background: #cc0" );
			$s1->appendChild( mktext( $session, $t1, $offset, $endw, $width ) );
			$s2 = $session->make_element( "span", style=>"background: #cc0" );
			$s2->appendChild( mktext( $session, $t2, $offset, $endw, $width ) );
			if( $h1>$h2 )
			{
				$s2->appendChild( $session->make_text( "\n"x($h1-$h2) ) );
			}
			if( $h2>$h1 )
			{
				$s1->appendChild( $session->make_text( "\n"x($h2-$h1) ) );
			}
		}
		$f1->appendChild( $s1 );
		$f2->appendChild( $s2 );
		$f1->appendChild( $session->make_text( "</$name1>\n" ) );
		$f2->appendChild( $session->make_text( "</$name2>\n" ) );
		return( $f1, $f2 );
	}
		
	
	$f1->appendChild( $session->make_text( "  "x$indent ) );
	$f1->appendChild( $session->make_text( "<$name1>\n" ) );
	$f2->appendChild( $session->make_text( "  "x$indent ) );
	$f2->appendChild( $session->make_text( "<$name2>\n" ) );
	my $c1 = 0;
	my $c2 = 0;
	my( $r1, $r2 );
	while( $c1<scalar @list1 && $c2<scalar @list2 )
	{
		if( diff( $list1[$c1], $list2[$c2] ) )
		{
			if( $c1+1<scalar @list1 )
			{
				my $removedto = 0;
				for(my $i=$c1+1;$i<scalar @list1;++$i)
				{
					if( !diff( $list1[$i], $list2[$c2] ) )
					{
						$removedto = $i;
						last;
					}
				}
				if( $removedto )
				{
					$r1 = $session->make_element( "span", style=>"background: #f88" );
					for(my $i=$c1;$i<$removedto;++$i)
					{
						my( $rem, $pad ) = render_xml( $session, $list1[$i], $indent+1, 1, $width );
						$r1->appendChild( $rem );
						$f2->appendChild( $pad );
					}
					$f1->appendChild( $r1 );
					$c1 = $removedto;
					next;
				}
			} 

			if( $c2+1<scalar @list2 )
			{
				my $addedto = 0;
				for(my $i=$c2+1;$i<scalar @list2;++$i)
				{
					if( !diff( $list2[$i], $list1[$c1] ) )
					{
						$addedto = $i;
						last;
					}
				}

				if( $addedto )
				{
					$r2 = $session->make_element( "span", style=>"background: #8f8" );
					for(my $i=$c2;$i<$addedto;++$i)
					{
						my( $add, $pad ) = render_xml( $session, $list2[$i], $indent+1, 1, $width );
						$r2->appendChild( $add );
						$f1->appendChild( $pad );
					}
					$f2->appendChild( $r2 );
					$c2 = $addedto;
					next;
				}
			}

			( $r1, $r2 ) = render_xml_diffs( $session, $list1[$c1], $list2[$c2], $indent+1, $width );
		}	
		else
		{
			$r1 = $session->make_element( "span" );
			$r1->appendChild( render_xml( $session, $list1[$c1], $indent+1, 0, $width ) );
			$r2 = $session->make_element( "span" );
			$r2->appendChild( render_xml( $session, $list2[$c2], $indent+1, 0, $width ) );
		}
		$f1->appendChild( $r1 );
		$f2->appendChild( $r2 );
		++$c1;
		++$c2;
	}

	# print any straglers.

	# any removed
	if( $c1<scalar @list1 )
	{
		$r1 = $session->make_element( "span", style=>"background: #f88" );
		for(my $i=$c1;$i<scalar @list1;++$i)
		{
			my( $rem, $pad ) = render_xml( $session, $list1[$i], $indent+1, 1, $width );
			$r1->appendChild( $rem );
			$f2->appendChild( $pad );
		}
		$f1->appendChild( $r1 );
	}

	# any added
	if( $c2<scalar @list2 )
	{
		my $r2 = $session->make_element( "span", style=>"background: #8f8" );
		for(my $i=$c2;$i<scalar @list2;++$i)
		{
			my( $add, $pad ) = render_xml( $session, $list2[$i], $indent+1, 1, $width );
			$f1->appendChild( $pad );
			$r2->appendChild( $add );
		}
		$f2->appendChild( $r2 );
	}

	$f1->appendChild( $session->make_text( "  "x$indent ) );
	$f1->appendChild( $session->make_text( "</$name1>\n" ) );
	$f2->appendChild( $session->make_text( "  "x$indent ) );
	$f2->appendChild( $session->make_text( "</$name2>\n" ) );

	return( $f1, $f2 );
}

	

######################################################################
#
# ($xhtml, [$xhtml_padding]) = EPrints::DataObj::History::render_domtree( $session, $tree, $indent, $make_padded, $width )
#
# Render the given tree as XHTML (showing the actual XML structure).
#
# If make_padded is true then also generate another element, which is 
# empty but the same height to be used in the other column to keep
# things level.
#
######################################################################

sub render_xml
{
	my( $session,$domtree,$indent,$mkpadder,$width ) = @_;

	if( EPrints::XML::is_dom( $domtree, "Text" ) )
	{
		my $v = $domtree->nodeValue;
		if( $v=~m/^[\s\r\n]*$/ )
		{
			if( $mkpadder ) { return( $session->make_doc_fragment, $session->make_doc_fragment ); }
			return $session->make_doc_fragment;
		}
		my $r = $session->make_text( ("  "x$indent).$v."\n" );
		if( $mkpadder ) { return( $r, $session->make_text( "\n" ) ); }
		return $r;
	}

	if( EPrints::XML::is_dom( $domtree, "Element" ) )
	{
		my $t = '';
		my $justtext = 1;

		foreach my $cnode ( $domtree->getChildNodes )
		{
			if( EPrints::XML::is_dom( $cnode,"Element" ) )
			{
				$justtext = 0;
				last;
			}
			if( EPrints::XML::is_dom( $cnode,"Text" ) )
			{
				$t.=$cnode->nodeValue;
			}
		}
		my $name = $domtree->nodeName;
		my $f = $session->make_doc_fragment;
		my $padder;
		if( $mkpadder ) { $padder = $session->make_doc_fragment; }
		if( $justtext )
		{
			my $offset = $indent*2+length($name)+2;
			my $endw = length($name)+3;
			$f->appendChild( $session->make_text( "  "x$indent ) );
			$t = "" if( $t =~ m/^[\s\r\n]*$/ );
			$f->appendChild( $session->make_text( "<$name>" ) );
			$f->appendChild( mktext( $session, $t, $offset, $endw, $width ) );
			$f->appendChild( $session->make_text( "</$name>\n" ) );
			if( $mkpadder ) { 
				$padder->appendChild( $session->make_text( "\n" ) ); 
				$padder->appendChild( mkpad( $session, $t, $offset, $endw, $width ) );
			}
		}
		else
		{
			$f->appendChild( $session->make_text( "  "x$indent ) );
			$f->appendChild( $session->make_text( "<$name>\n" ) );
			if( $mkpadder ) { $padder->appendChild( $session->make_text( "\n" ) ); }
	
			foreach my $cnode ( $domtree->getChildNodes )
			{
				my( $sub, $padsub ) = render_xml( $session,$cnode, $indent+1, $mkpadder, $width );
				if( $mkpadder ) { $padder->appendChild( $padsub ); }
				$f->appendChild( $sub );
			}

			$f->appendChild( $session->make_text( "  "x$indent ) );
			$f->appendChild( $session->make_text( "</$name>\n" ) );
			if( $mkpadder ) { $padder->appendChild( $session->make_text( "\n" ) ); }
		}
		if( $mkpadder ) { return( $f, $padder ); }
		return $f;
	}
	return( $session->make_text( "eh?:".ref($domtree) ), $session->make_doc_fragment );
}

######################################################################
#
# $boolean = EPrints::DataObj::History::diff( $tree1, $tree2 )
#
# Return true if the XML trees are not the same, otherwise false.
#
######################################################################

sub diff
{
	my( $a, $b ) = @_;

	if( defined $a && !defined $b )
	{
		return 1;
	}
	if( !defined $a && defined $b )
	{
		return 1;
	}
	if( ref( $a ) ne ref( $b ) )
	{
		return 1;
	}
		
	if( $a->nodeName ne $b->nodeName )
	{
		return 1;
	}
		

	
	if( EPrints::XML::is_dom( $a, "Text" ) )
	{
		my $va = $a->nodeValue;
		my $vb = $b->nodeValue;

		# both empty
		if( $va=~m/^[\s\r\n]*$/ && $vb=~m/^[\s\r\n]*$/ )
		{
			return 0;
		}

		if( $va eq $vb )	
		{
			return 0;
		}

		return 1;
	}

	if( EPrints::XML::is_dom( $a, "Element" ) )
	{
		my @alist = $a->getChildNodes;
		my @blist = $b->getChildNodes;
		return( 1 ) if( scalar @alist != scalar @blist );
		for( my $i=0;$i<scalar @alist;++$i )
		{
			return 1 if diff( $alist[$i], $blist[$i] );
		}
		return 0;
	}

	return 0;
}

######################################################################
#
# @lines = EPrints::DataObj::History::_mktext( $session, $text, $offset, $endw, $width )
#
# Return the $text string broken into lines which are $width long, or
# less.
#
# Inserts a 90 degree arrow at the end of each broken line to indicate
# that it has been broken.
#
######################################################################

sub _mktext
{
	my( $session, $text, $offset, $endw, $width ) = @_;

	return () unless length( $text );

	my $lb = chr(8626);
	my @bits = split(/[\r\n]/, $text );
	my @b2 = ();
	
	foreach my $t2 ( @bits )
	{
		while( $offset+length( $t2 ) > $width )
		{
			my $cut = $width-1-$offset;
			push @b2, substr( $t2, 0, $cut ).$lb;
			$t2 = substr( $t2, $cut );
			$offset = 0;
		}
		if( $offset+$endw+length( $t2 ) > $width )
		{
			push @b2, $t2.$lb, "";
		}
		else
		{
			push @b2, $t2;
		}
	}

	return @b2;
}

######################################################################
#
# $boolean = EPrints::DataObj::History::diff( $tree1, $tree2 )
#
# Return true if the XML trees are not the same, otherwise false.
# render $text into wrapped XML DOM.
#
######################################################################

sub mktext
{
	my( $session, $text, $offset, $endw, $width ) = @_;

	my @bits = _mktext( $session, $text, $offset, $endw, $width );

	return $session->make_text( join( "\n", @bits ) );
}

######################################################################
#
# $xhtml = EPrints::DataObj::History::mkpad( $session, $text, $offset, $endw, $width )
#
# Return DOM of vertical padding equiv. to the lines that would
# be needed to render $text.
#
######################################################################


sub mkpad
{
	my( $session, $text, $offset, $endw, $width ) = @_;

	my @bits = _mktext( $session, $text, $offset, $endw, $width );

	return $session->make_text( "\n"x((scalar @bits)-1) );
}

sub set_dataobj_xml
{
	my( $self, $dataobj ) = @_;

	use bytes;

	my $xml = $dataobj->to_xml( hide_volatile => 1 );

	my $data = "<?xml version='1.0' encoding='utf-8' ?>\n";
	$data .= $self->{session}->xml->to_string( $xml, indent => 1 );
	# $data will be bytes due to "use bytes" above

	$self->{session}->xml->dispose( $xml );

	$self->add_stored_file( "dataobj.xml", \$data, length($data) );
}

######################################################################
1;
######################################################################
=pod

=back

=cut


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

