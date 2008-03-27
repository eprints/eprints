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

=head2 Constructor Methods

=over 4

=cut

######################################################################

=item $thing = EPrints::DataObj::Import->new( $session, $importid )

The data object identified by $importid.

=cut

sub new
{
	my( $class, $session, $importid ) = @_;

	return $session->get_database->get_single( 
			$session->get_repository->get_dataset( "import" ), 
			$importid );
}

=item $thing = EPrints::DataObj::Import->new_from_data( $session, $known )

A new C<EPrints::DataObj::Import> object containing data $known (a hash reference).

=cut

sub new_from_data
{
	my( $class, $session, $known ) = @_;

	return $class->SUPER::new_from_data(
			$session,
			$known,
			$session->get_repository->get_dataset( "import" ) );
}

######################################################################

=head2 Class Methods

=cut

######################################################################

=item EPrints::DataObj::Import::remove_all( $session )

Remove all records from the license dataset.

=cut

sub remove_all
{
	my( $class, $session ) = @_;

	my $ds = $session->get_repository->get_dataset( "import" );
	foreach my $obj ( $session->get_database->get_all( $ds ) )
	{
		$obj->remove();
	}
	return;
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

=item ($tags,$labels) = EPrints::DataObj::Import::tags_and_labels( $session, $dataset )

Returns the tags and labels for all records in this dataset.

=cut

sub tags_and_labels
{
	my( $class, $session, $ds ) = @_;

	my $searchexp = EPrints::Search->new(
		allow_blank => 1,
		custom_order => "importid",
		session => $session,
		dataset => $ds );

	$searchexp->perform_search();
	
	my( @tags, %labels );
	foreach my $l ( $searchexp->get_records() )
	{
		push @tags, my $id = $l->get_value( "importid" );
		$labels{$id} = $l->get_label();
	}

	$searchexp->dispose();

	return( \@tags, \%labels );
}

######################################################################

=head2 Object Methods

=cut

######################################################################

=item $foo = $thing->remove()

Remove this record from the data set (see L<EPrints::Database>).

=cut

sub remove
{
	my( $self ) = @_;
	
	return $self->{session}->get_database->remove(
		$self->{dataset},
		$self->get_id );
}

=item $list = $import->run()

Run this bulk import. Returns a list of EPrints created.

=cut

sub run
{
	my( $self ) = @_;

	my $dataset = $self->{session}->get_repository->get_dataset( "eprint" );

	my $plugin = $self->{session}->plugin( "Import::XML" );

	my $url = $self->get_value( "url" );
	my $base_uri = $self->get_value( "source" );
	my $importid = $self->get_id;

	return unless EPrints::Utils::is_set( $url );

	$self->clear();

	my $file = File::Temp->new;

	my $ua = LWP::UserAgent->new;
	my $r = $ua->get( $url, ":content_file" => "$file" );

	return unless $r->is_success;

	my $doc = EPrints::XML::parse_xml( "$file" );

	my $root = $doc->documentElement;

	foreach my $eprint ($root->getElementsByTagName( "eprint" ))
	{
		my( $_documents ) = $root->getElementsByTagName( "documents" );
		$eprint->removeChild( $_documents );

		my( $_eprintid ) = $eprint->getElementsByTagName( "eprintid" );
		$eprint->removeChild( $_eprintid );
		my $_import = $doc->createElement( "import" );
		my $_importid = $doc->createElement( "importid" );
		my $_derivedfrom = $doc->createElement( "derivedfrom" );

		$eprint->appendChild( $_import );
		$_import->appendChild( $_importid );
		$_importid->appendChild( $doc->createTextNode( $importid ) );

		$_import->appendChild( $_derivedfrom );
		my $url = $base_uri . EPrints::Utils::tree_to_utf8($_eprintid) . "/";
		$_derivedfrom->appendChild( $doc->createTextNode( $url ) );
	}


	print STDERR $doc->toString;

	my $xml_file = File::Temp->new;

	print $xml_file $doc->toString;
	EPrints::XML::dispose($doc);

	seek($xml_file,0,0);

	my $list = $plugin->input_fh(
		dataset => $dataset,
		fh => $xml_file,
	);

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
	$searchexp->add_field( $dataset->get_field( "import_importid" ), $self->get_id );

	my $list = $searchexp->perform_search;

	$list->map(sub {
		my( $session, $dataset, $eprint ) = @_;

		$eprint->remove();
	});
}

1;

__END__

=back

=head1 SEE ALSO

L<EPrints::DataObj> and L<EPrints::DataSet>.

=cut

