######################################################################
#
# EPrints::Subscription
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

=pod

=head1 NAME

B<EPrints::Subscription> - undocumented

=head1 DESCRIPTION

undocumented

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  From DataObj.
#
######################################################################

package EPrints::Subscription;
@ISA = ( 'EPrints::DataObj' );
use EPrints::DataObj;

use EPrints::Database;
use EPrints::Utils;
use EPrints::MetaField;
use EPrints::SearchExpression;
use EPrints::Session;
use EPrints::User;

### SUBS MUST BE FLAGGED AS BULK cjg

use strict;


######################################################################
=pod

=item $thing = EPrints::Subscription->get_system_field_info

undocumented

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"subid", type=>"int", required=>1 },

		{ name=>"userid", type=>"int", required=>1 },

		{ 
			name => "spec",
			type => "search",
			datasetid => "archive",
			fieldnames => "subscriptionfields"
		},

		{ name=>"frequency", type=>"set", required=>1,
			options=>["never","daily","weekly","monthly"] } 
	);
}

######################################################################
=pod

=item EPrints::Subscription->new( $session, $id )

undocumented

=cut
######################################################################

sub new
{
	my( $class, $session, $id ) = @_;

	return $session->get_db()->get_single( 	
		$session->get_archive()->get_dataset( "subscription" ),
		$id );
}

######################################################################
=pod

=item $thing = EPrints::Subscription->new_from_data( $session, $data )

undocumented

=cut
######################################################################

sub new_from_data
{
	my( $class, $session, $data ) = @_;

	my $self = {};
	bless $self, $class;

	$self->{data} = $data;
	$self->{dataset} = $session->get_archive()->get_dataset( 
		"subscription" );
	$self->{session} = $session;
	
	return $self;
}

######################################################################
=pod

=item $thing = EPrints::Subscription->create( $session, $userid )

undocumented

=cut
######################################################################

sub create
{
	my( $class, $session, $userid ) = @_;

	my $subs_ds = $session->get_archive()->get_dataset( "subscription" );
	my $id = $session->get_db()->counter_next( "subscriptionid" );

	my $data = {
		subid => $id,
		userid => $userid,
		frequency => 'never',
		spec => ''
	};

	$session->get_archive()->call(
		"set_subscription_defaults",
		$data,
		$session );

	# Add the subscription to the database
	$session->get_db()->add_record( $subs_ds, $data );

	# And return it as an object
	return EPrints::Subscription->new( $session, $id );
}




######################################################################
=pod

=item $foo = $thing->remove

Remove the subscription.

=cut
######################################################################

sub remove
{
	my( $self ) = @_;

	my $subs_ds = $self->{session}->get_archive()->get_dataset( 
		"subscription" );
	
	my $success = $self->{session}->get_db()->remove(
		$subs_ds,
		$self->get_value( "subid" ) );

	return $success;
}


######################################################################
=pod

=item $foo = $thing->commit

undocumented

=cut
######################################################################

sub commit
{
	my( $self ) = @_;
	
	$self->{session}->get_archive()->call( 
		"set_subscription_automatic_fields", 
		$self );

	my $subs_ds = $self->{session}->get_archive()->get_dataset( 
		"subscription" );
	my $success = $self->{session}->get_db()->update(
		$subs_ds,
		$self->{data} );

	return $success;
}


######################################################################
=pod

=item $foo = $thing->get_user

undocumented

=cut
######################################################################

sub get_user
{
	my( $self ) = @_;

	return EPrints::User->new( 
		$self->{session},
		$self->get_value( "userid" ) );
}


######################################################################
=pod

=item $searchexp = $thing->make_searchexp

undocumented

=cut
######################################################################

sub make_searchexp
{
	my( $self ) = @_;

	my $ds = $self->{session}->get_archive()->get_dataset( 
		"subscription" );
	
	return $ds->get_field( 'spec' )->make_searchexp( 
		$self->{session},
		$self->get_value( 'spec' ) );
}


######################################################################
=pod

=item $thing->send_out_subscription

undocumented

=cut
######################################################################

sub send_out_subscription
{
	my( $self ) = @_;


	my $freq = $self->get_value( "frequency" );

	if( $freq eq "never" )
	{
		$self->{session}->get_archive->log( 
			"Attempt to send out a subscription for a\n".
			"which has frequency 'never'\n" );
		return;
	}
		
	my $user = $self->get_user;

	if( !defined $user )
	{
		$self->{session}->get_archive->log( 
			"Attempt to send out a subscription for a\n".
			"non-existant user. Subid#".$self->get_id."\n" );
		return;
	}

	my $origlangid = $self->{session}->get_langid;
	
	$self->{session}->change_lang( $user->get_value( "lang" ) );

	my $searchexp = $self->make_searchexp;
	# get the description before we fiddle with searchexp
 	my $searchdesc = $searchexp->render_description,

	my $datestamp_field = $self->{session}->get_archive()->get_dataset( 
		"archive" )->get_field( "datestamp" );

	if( $freq eq "daily" )
	{
		# Get the date for yesterday
		my $yesterday = EPrints::Utils::get_datestamp( 
			time - (24*60*60) );
		# Get from the last day
		$searchexp->add_field( 
			$datestamp_field,
			$yesterday."-" );
	}
	elsif( $freq eq "weekly" )
	{
		# Work out date a week ago
		my $last_week = EPrints::Utils::get_datestamp( 
			time - (7*24*60*60) );

		# Get from the last week
		$searchexp->add_field( 
			$datestamp_field,
			$last_week."-" );
	}
	elsif( $freq eq "monthly" )
	{
		# Get today's date
		my( $year, $month, $day ) = EPrints::Utils::get_date( time );
		# Substract a month		
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
	$searchexp->set_property( "use_oneshot_cache", 1 );

	my $url = $self->{session}->get_archive->get_conf( "perl_url" ).
		"/users/subscribe";
	my $freqphrase = $self->{session}->html_phrase(
		"lib/subscription:".$freq );
	my $info = {};
	$info->{mail} = $self->{session}->make_doc_fragment;
	$info->{mail}->appendChild( 
		$self->{session}->html_phrase( 
			"lib/subscription:blurb",
			howoften => $freqphrase,
			search => $searchdesc,
			url => $self->{session}->make_text( $url ) ) );

	my $fn = sub {
		my( $session, $dataset, $item, $info ) = @_;

		my $p = $session->make_element( "p" );
		$p->appendChild( $item->render_citation );
		$p->appendChild( $session->make_element( "br" ) );
		$p->appendChild( $session->make_text( $item->get_url ) );
		
		$info->{mail}->appendChild( $p );
	};

	$info->{mail}->appendChild( $self->{session}->make_element( "hr" ) );
	$searchexp->perform_search;
	$info->{mail}->appendChild( $self->{session}->html_phrase(
		"lib/subscription:matches",
		n => $self->{session}->make_text( $searchexp->count ) ) );
	$searchexp->map( $fn, $info );
	$searchexp->dispose;

	$user->mail( 
		"lib/subscription:sub_subj",
		$info->{mail} );

	$info->{mail}->dispose;

	$self->{session}->change_lang( $origlangid );
}


######################################################################
=pod

=item EPrints::Subscription::process_set( $session, $frequency );

undocumented

=cut
######################################################################

sub process_set
{
	my( $session, $frequency ) = @_;

	my $subs_ds = $session->get_archive->get_dataset( "subscription" );

	my $searchexp = EPrints::SearchExpression->new(
		session => $session,
		dataset => $subs_ds );

	$searchexp->add_field(
		$subs_ds->get_field( "frequency" ),
		$frequency );

	my $fn = sub {
		my( $session, $dataset, $item, $info ) = @_;

		$item->send_out_subscription;
		if( $session->get_noise >= 2 )
		{
			print "Sending out subscription #".$item->get_id."\n";
		}
	};

	$searchexp->perform_search;
	$searchexp->map( $fn, {} );
	$searchexp->dispose;
}

=pod

=back

=cut

1;
