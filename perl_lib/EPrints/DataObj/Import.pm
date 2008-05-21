######################################################################
#
# EPrints::DataObj::Import
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

B<EPrints::DataObj::Import> - bulk imports logging

=head1 DESCRIPTION

Inherits from L<EPrints::DataObj>.

=head1 INSTANCE VARIABLES

=over 4

=item $obj->{ "data" }

=item $obj->{ "dataset" }

=item $obj->{ "session" }

=back

=head1 CORE FIELDS

=over 4

=item importid

Unique id for the import.

=item datestamp

Time of import.

=item userid

Id of the user responsible for causing the import.

=item source_repository

Source entity from which this import came.

=item url

Location of the imported content (e.g. the file name).

=item description

Human-readable description of the import.

=back

=head1 METHODS

=over 4

=cut

package EPrints::DataObj::Import;

@ISA = ( 'EPrints::DataObj' );

use EPrints;

use strict;

=item $thing = EPrints::DataObj::Import->get_system_field_info

Core fields contained in a Web import.

=cut

sub get_system_field_info
{
	my( $class ) = @_;

	return
	( 
		{ name=>"importid", type=>"int", required=>1, can_clone=>0 },

		{ name=>"datestamp", type=>"time", required=>1, },

		{ name=>"userid", type=>"itemref", required=>0, datasetid => "user" },

		{ name=>"source_repository", type=>"text", required=>0, },

		{ name=>"url", type=>"longtext", required=>0, },

		{ name=>"description", type=>"longtext", required=>0, },

	);
}

######################################################################

=back

=head2 Class Methods

=cut

######################################################################
=pod

=item $dataset = EPrints::DataObj::Import->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut
######################################################################

sub get_dataset_id
{
	return "import";
}

######################################################################

=item $defaults = EPrints::DataObj::Import->get_defaults( $session, $data )

Return default values for this object based on the starting data.

=cut

######################################################################

sub get_defaults
{
	my( $class, $session, $data ) = @_;
	
	$data->{importid} = $session->get_database->counter_next( "importid" );

	$data->{datestamp} = EPrints::Time::get_iso_timestamp();

	return $data;
}

######################################################################

=head2 Object Methods

=cut

######################################################################

=item $list = $import->run( $processor )

Run this bulk import. Returns a list of EPrints created. $processor is used for reporting errors.

=cut

sub run
{
	my( $self, $processor ) = @_;

	my $session = $self->{session};
	my $dataset = $self->{session}->get_repository->get_dataset( "eprint" );

	my $plugin = $self->{session}->plugin( "Import::XML" );

	my $url = $self->get_value( "url" );
	my $importid = $self->get_id;

	if( !EPrints::Utils::is_set( $url ) )
	{
		$processor->add_message( "error", $session->make_text( "Can't run import that doesn't contain a URL" ) );
		return;
	}

	my $file = File::Temp->new;

	my $ua = LWP::UserAgent->new;
	my $r = $ua->get( $url, ":content_file" => "$file" );

	if( !$r->is_success )
	{
		my $err = $session->make_doc_fragment;
		$err->appendChild( $session->make_text( "Error requesting " ) );
		$err->appendChild( $session->make_link( $url ) );
		$err->appendChild( $session->make_text( ": ".$r->status_line ) );
		$processor->add_message( "error", $err );
		return;
	}

	my $doc;
	
	eval {
		$doc = EPrints::XML::parse_xml( "$file" );
	};

	if( $@ )
	{
		my $err = $session->make_doc_fragment;
		$err->appendChild( $session->make_text( "Error requesting " ) );
		$err->appendChild( $session->make_link( $url ) );
		$err->appendChild( $session->make_text( ": ".$@ ) );
		$processor->add_message( "error", $err );
		return;
	}

	my $root = $doc->documentElement;

	foreach my $eprint ($root->getElementsByTagName( "eprint" ))
	{
		my( $_eprintid ) = $eprint->getElementsByTagName( "eprintid" );
		my( $_eprint_status ) = $eprint->getElementsByTagName( "eprint_status" );
		my( $_userid ) = $eprint->getElementsByTagName( "userid" );
		$eprint->removeChild( $_userid ) if $_userid;

		my $sourceid = EPrints::Utils::tree_to_utf8($_eprintid);

		my $old_eprint = $self->get_from_source( $sourceid );

		if( defined( $old_eprint ) )
		{
			$_eprintid->removeChild( $_eprintid->firstChild );
			$_eprintid->appendChild( $doc->createTextNode( $old_eprint->get_id ) );
			$_eprint_status->removeChild( $_eprint_status->firstChild );
			$_eprint_status->appendChild( $doc->createTextNode( $old_eprint->get_value( "eprint_status" ) ) );
		}
		else
		{
			$eprint->removeChild( $_eprintid );
		}

		my $_importid = $doc->createElement( "importid" );
		my $_source = $doc->createElement( "source" );

		$eprint->appendChild( $_importid );
		$_importid->appendChild( $doc->createTextNode( $importid ) );

		$eprint->appendChild( $_source );
		$_source->appendChild( $doc->createTextNode( $sourceid ) );
	}


#	print STDERR $doc->toString;

	my $xml_file = File::Temp->new;

	print $xml_file $doc->toString;
	EPrints::XML::dispose($doc);

	seek($xml_file,0,0);

	my $config = $session->get_repository->{config};

	my $enable_import_ids = $config->{enable_import_ids};
	$config->{enable_import_ids} = 1;
	my $enable_web_imports = $config->{enable_web_imports};
	$config->{enable_web_imports} = 1;

	$self->clear();

	my $list = $plugin->input_fh(
		dataset => $dataset,
		fh => $xml_file,
	);

	$config->{enable_import_ids} = $enable_import_ids;
	$config->{enable_web_imports} = $enable_web_imports;

	return $list;
}

=item $import->clear()

Clear the contents of this bulk import.

=cut

sub clear
{
	my( $self ) = @_;

	my $dataset = $self->{session}->get_repository->get_dataset( "eprint" );

	my $searchexp = EPrints::Search->new(
		session => $self->{session},
		dataset => $dataset,
	);

	$searchexp->add_field( $dataset->get_field( "importid" ), $self->get_id );

	my $list = $searchexp->perform_search;

	$list->map(sub {
		my( $session, $dataset, $eprint ) = @_;

		$eprint->remove();
	});
}

=item $eprint = $import->get_from_source( $sourceid )

Get the $eprint that is from this import set and identified by $sourceid.

=cut

sub get_from_source
{
	my( $self, $sourceid ) = @_;

	my $dataset = $self->{session}->get_repository->get_dataset( "eprint" );

	my $searchexp = EPrints::Search->new(
		session => $self->{session},
		dataset => $dataset,
	);

	$searchexp->add_field( $dataset->get_field( "importid" ), $self->get_id );
	$searchexp->add_field( $dataset->get_field( "source" ), $sourceid );

	my $list = $searchexp->perform_search;

	return $list->count > 0 ? $list->get_records(0,1) : undef;
}

1;

__END__

=back

=head1 SEE ALSO

L<EPrints::DataObj> and L<EPrints::DataSet>.

=cut

