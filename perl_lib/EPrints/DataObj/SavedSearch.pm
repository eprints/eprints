######################################################################
#
# EPrints::DataObj::SavedSearch
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::DataObj::SavedSearch> - Single saved search.

=head1 DESCRIPTION

A saved search is a sub class of EPrints::DataObj.

Each one belongs to one and only one user, although one user may own
multiple saved searches.

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  From DataObj.
#
######################################################################

package EPrints::DataObj::SavedSearch;

@ISA = ( 'EPrints::DataObj::SubObject' );

use EPrints;

use strict;


######################################################################
=pod

=item $field_config = EPrints::DataObj::SavedSearch->get_system_field_info

Return an array describing the system metadata of the saved search.
dataset.

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"id", type=>"counter", required=>1, import=>0, can_clone=>1,
			sql_counter=>"savedsearchid" },

		{ name=>"userid", type=>"itemref", 
			datasetid=>"user", required=>1 },

		{ name=>"name", type=>"text" },

		{ name => "spec", type => "search", datasetid => "eprint",
			default_value=>"" },

		{ name=>"frequency", type=>"set", required=>1,
			options=>["never","daily","weekly","monthly"],
			default_value=>"never" },

		{ name=>"mailempty", type=>"boolean", input_style=>"radio",
			default_value=>"TRUE" },

		{ name=>"public", type=>"boolean", input_style=>"radio",
			default_value=>"FALSE" },
	);
}

sub get_dataset
{
	my( $self ) = @_;

	return $self->is_set( "public" ) && $self->value( "public" ) eq "TRUE" ?
			$self->{session}->dataset( "public_saved_search" ) :
			$self->{session}->dataset( "saved_search" );
}

######################################################################
=pod

=item $dataset = EPrints::DataObj::SavedSearch->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut
######################################################################

sub get_dataset_id
{
	return "saved_search";
}

######################################################################
# =pod
# 
# =item $saved_search = EPrints::DataObj::SavedSearch->create( $session, $userid )
# 
# Create a new saved search. entry in the database, belonging to user
# with id $userid.
# 
# =cut
######################################################################

sub create
{
	my( $class, $session, $userid ) = @_;

	return EPrints::DataObj::SavedSearch->create_from_data( 
		$session, 
		{ userid=>$userid },
		$session->dataset( "saved_search" ) );
}

######################################################################
=pod

=item $success = $saved_search->commit( [$force] )

Write this object to the database.

If $force isn't true then it only actually modifies the database
if one or more fields have been changed.

=cut
######################################################################

sub commit
{
	my( $self, $force ) = @_;
	
	$self->update_triggers();

	if( !defined $self->{changed} || scalar( keys %{$self->{changed}} ) == 0 )
	{
		# don't do anything if there isn't anything to do
		return( 1 ) unless $force;
	}

	my $success = $self->SUPER::commit( $force );

	return $success;
}


######################################################################
=pod

=item $user = $saved_search->get_user

Return the EPrints::DataObj::User which owns this saved search.

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

######################################################################
=pod

=item $searchexp = $saved_search->make_searchexp

Return a EPrints::Search describing how to find the eprints
which are in the scope of this saved search.

=cut
######################################################################

sub make_searchexp
{
	my( $self ) = @_;

	my $ds = $self->{session}->get_repository->get_dataset( 
		"saved_search" );
	
	return $ds->get_field( 'spec' )->make_searchexp( 
		$self->{session},
		$self->get_value( 'spec' ) );
}


######################################################################
=pod

=item $saved_search->send_out_alert

Send out an email for this subcription. If there are no matching new
items then an email is only sent if the saved search has mailempty
set to true.

=cut
######################################################################

sub send_out_alert
{
	my( $self ) = @_;

	my $freq = $self->get_value( "frequency" );

	if( $freq eq "never" )
	{
		$self->{session}->get_repository->log( 
			"Attempt to send out an alert for a\n".
			"which has frequency 'never'\n" );
		return;
	}
		
	my $user = $self->get_user;

	if( !defined $user )
	{
		$self->{session}->get_repository->log( 
			"Attempt to send out an alert for a\n".
			"non-existent user. SavedSearch ID#".$self->get_id."\n" );
		return;
	}

	# change language temporarily to the user's language
	local $self->{session}->{lang} = $user->language();

	my $searchexp = $self->make_searchexp;

	if( $searchexp->isa( "EPrints::Plugin::Search::Xapian" ) )
	{
		$self->{session}->log( "send_alerts: Xapian search engine not yet supported. Cannot send alerts for SavedSearch id=".$self->id );
		return;
	}

	# get the description before we fiddle with searchexp
 	my $searchdesc = $searchexp->render_description,

	my $datestamp_field = $self->{session}->get_repository->get_dataset( 
		"archive" )->get_field( "datestamp" );

	if( $freq eq "daily" )
	{
		# Get the date for yesterday
		my $yesterday = EPrints::Time::get_iso_date( 
			time - (24*60*60) );
		# Get from the last day
		$searchexp->add_field( 
			$datestamp_field,
			$yesterday."-" );
	}
	elsif( $freq eq "weekly" )
	{
		# Work out date a week ago
		my $last_week = EPrints::Time::get_iso_date( 
			time - (7*24*60*60) );

		# Get from the last week
		$searchexp->add_field( 
			$datestamp_field,
			$last_week."-" );
	}
	elsif( $freq eq "monthly" )
	{
		# Get today's date
		my( $year, $month, $day ) = EPrints::Time::get_date_array( time );
		# Subtract a month
		$month--;

		# Check for year "wrap"
		if( $month==0 )
		{
			$month = 12;
			$year--;
		}
		
		# Ensure two digits in month
		while( length $month < 2 )
		{
			$month = "0".$month;
		}
		my $last_month = $year."-".$month."-".$day;
		# Add the field searching for stuff from a month onwards
		$searchexp->add_field( 
			$datestamp_field,
			$last_month."-" );
	}

	my $settings_url = $self->{session}->get_repository->get_conf( "http_cgiurl" ).
		"/users/home?screen=Workflow::Edit&dataset=saved_search&dataobj=".$self->get_id;
	my $freqphrase = $self->{session}->html_phrase(
		"lib/saved_search:".$freq );

	my $fn = sub {
		my( $session, $dataset, $item, $info ) = @_;

		my $p = $session->make_element( "p" );
		$p->appendChild( $item->render_citation_link( $session->config( "saved_search_citation" )));
		$info->{matches}->appendChild( $p );
#		$info->{matches}->appendChild( $session->make_text( $item->get_url ) );
	};


	my $list = $searchexp->perform_search;
	my $mempty = $self->get_value( "mailempty" );
	$mempty = 0 unless defined $mempty;

	if( $list->count > 0 || $mempty eq 'TRUE' )
	{
		my $info = {};
		$info->{matches} = $self->{session}->make_doc_fragment;
		$list->map( $fn, $info );

		my $mail = $self->{session}->html_phrase( 
				"lib/saved_search:mail",
				howoften => $freqphrase,
				n => $self->{session}->make_text( $list->count ),
				search => $searchdesc,
				matches => $info->{matches},
				url => $self->{session}->render_link( $settings_url ) );
		if( $self->{session}->get_noise >= 2 )
		{
			print "Sending out alert #".$self->get_id." to ".$user->get_value( "email" )."\n";
		}
		$user->mail( 
			"lib/saved_search:sub_subj",
			$mail );
		EPrints::XML::dispose( $mail );
	}
	$list->dispose;
}


######################################################################
=pod

=item EPrints::DataObj::SavedSearch::process_set( $session, $frequency );

Static method. Calls send_out_alert on every saved search 
with a frequency matching $frequency.

Also saves a file logging that the alerts for this frequency
was sent out at the current time.

=cut
######################################################################

sub process_set
{
	my( $session, $frequency ) = @_;

	if( $frequency ne "daily" && 
		$frequency ne "weekly" && 
		$frequency ne "monthly" )
	{
		$session->get_repository->log( "EPrints::DataObj::SavedSearch::process_set called with unknown frequency: ".$frequency );
		return;
	}

	my $subs_ds = $session->dataset( "saved_search" );

	my $searchexp = EPrints::Search->new(
		session => $session,
		dataset => $subs_ds );

	$searchexp->add_field(
		$subs_ds->get_field( "frequency" ),
		$frequency );

	my $fn = sub {
		my( $session, $dataset, $item, $info ) = @_;

		$item->send_out_alert;
	};

	my $list = $searchexp->perform_search;
	$list->map( $fn, {} );

	my $statusfile = $session->config( "variables_path" ).
		"/alert-".$frequency.".timestamp";

	unless( open( TIMESTAMP, ">$statusfile" ) )
	{
		$session->get_repository->log( "EPrints::DataObj::SavedSearch::process_set failed to open\n$statusfile\nfor writing." );
	}
	else
	{
		print TIMESTAMP <<END;
# This file is automatically generated to indicate the last time
# this repository successfully completed sending the *$frequency* 
# alerts. It should not be edited.
END
		print TIMESTAMP EPrints::Time::human_time()."\n";
		close TIMESTAMP;
	}
}


######################################################################
=pod

=item $timestamp = EPrints::DataObj::SavedSearch::get_last_timestamp( $session, $frequency );

Static method. Return the timestamp of the last time this frequency 
of alert was sent.

=cut
######################################################################

sub get_last_timestamp
{
	my( $session, $frequency ) = @_;

	if( $frequency ne "daily" && 
		$frequency ne "weekly" && 
		$frequency ne "monthly" )
	{
		$session->get_repository->log( "EPrints::DataObj::SavedSearch::get_last_timestamp called with unknown\nfrequency: ".$frequency );
		return;
	}

	my $statusfile = $session->config( "variables_path" ).
		"/alert-".$frequency.".timestamp";

	unless( open( TIMESTAMP, $statusfile ) )
	{
		# can't open file. Either an error or file does not exist
		# either way, return undef.
		return;
	}

	my $timestamp = undef;
	while(<TIMESTAMP>)
	{
		next if m/^\s*#/;	
		next if m/^\s*$/;	
		s/\015?\012?$//s;
		$timestamp = $_;
		last;
	}
	close TIMESTAMP;

	return $timestamp;
}


######################################################################
=pod

=item $boolean = $user->has_owner( $possible_owner )

True if the users are the same record.

=cut
######################################################################

sub has_owner
{
	my( $self, $possible_owner ) = @_;

	if( $possible_owner->get_value( "userid" ) == $self->get_value( "userid" ) )
	{
		return 1;
	}

	return 0;
}

sub parent
{
	my( $self ) = @_;

	return $self->{session}->user( $self->value( "userid" ) );
}

sub get_url
{
	my( $self, $staff ) = @_;

	my $searchexp = $self->{session}->plugin( "Search" )->thaw( $self->value( "spec" ) );
	return undef if !defined $searchexp;

	return $searchexp->search_url;
}

=pod

=back

=cut

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

