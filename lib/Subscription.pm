######################################################################
#
#  EPrints Subscription Class
#
#   Holds information about a user subscription.
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

package EPrints::Subscription;

use EPrints::Database;
use EPrints::HTMLRender;
use EPrints::Mailer;
use EPrints::MetaField;
use EPrints::SearchExpression;
use EPrints::Session;
use EPrints::User;

### SUBS MUST BE FLAGGED AS BULK cjg

use strict;
#"frequency:set:never,Never (Off);daily,Daily;weekly,Weekly;monthly,Monthly:Frequency:1:1:1"

## WP1: BAD
sub get_system_field_info
{
	my( $class , $site ) = @_;

	return ( 
	{
		name=>"subid",
		type=>"text",
		required=>1,
		editable=>0
	},
	{
		name=>"username",
		type=>"text",
		required=>1,
		editable=>0
	},
	{
		name=>"spec",
		type=>"longtext",
		displaylines=>3,
		required=>1,
		editable=>0
	},
	{
		name=>"frequency",
		type=>"set",
		options=>["never","daily","weekly","monthly"],
		required=>1,
		editable=>1
	} );
}


######################################################################
#
# $subscription = new( $session, $subid, $dbrow )
#
#  Retrieve a subscription from the database. $row can be the row
#  for the subscription if it's been retrieved already.
#
######################################################################

## WP1: BAD
sub new
{
	my( $class, $session, $subid, $dbrow ) = @_;
	
	my $self = {};
	bless $self, $class;

	$self->{session} = $session;

	if( !defined $dbrow )
	{
		# Get the relevant row...
		my @row = $self->{session}->{database}->retrieve_single(
			EPrints::Database::table_name( "subscription" ),
			"subid",
			$subid );

		if( $#row == -1 )
		{
			# No such subscription
			return( undef );
		}

		$dbrow = \@row;
	}

	# Lob the row data into the relevant fields
	my @fields = $self->{session}->{metainfo}->get_fields( "subscription" );

	my $i=0;
	
	foreach (@fields)
	{
		$self->{$_->{name}} = $dbrow->[$i];
		$i++;
	}

	my @metafields = EPrints::SearchExpression::make_meta_fields(
		$self->{session},
		"eprint",
		$self->{session}->{site}->{subscription_fields} );

	# Get out the search expression
	$self->{searchexpression} = new EPrints::SearchExpression(
		$self->{session},
		"archive",
		1,
		1,
		\@metafields );

	$self->{searchexpression}->state_from_string( $self->{spec} )
		if( defined $self->{spec} && $self->{spec} ne "" );

	return( $self );
}


######################################################################
#
# $subscription = create( $session, $username )
#
#  Create a new subscription for the given user.
#
######################################################################

## WP1: BAD
sub create
{
	my( $class, $session, $username ) = @_;
	
	my $self = {};
	bless $self, $class;

	$self->{session} = $session;

	my $id = _generate_subid( $session, $username );
	
	$self->{subid} = $id;
	$self->{username} = $username;
	
# cjg add_record call
	$session->{database}->add_record( EPrints::Database::table_name( "subscription" ),
	                                  [ [ "subid", $self->{subid} ],
	                                    [ "username", $username ] ] );
	
	return( new EPrints::Subscription( $session, $id ) );
}


######################################################################
#
# $id = _generate_subid( $session, $username )
#
#  Generate an ID for a new subscription
#
######################################################################

## WP1: BAD
sub _generate_subid
{
	my( $session, $username ) = @_;
	
	my $cand = 0;
	my $found = 0;
	my $id;

	# Try to get an ID of the form username_0, username_1, ... until a free
	# one is found.	
	while( !$found )
	{
		$id = $username."_".$cand;
		
		# First find out if the candidate is taken
		my $rows = $session->{database}->retrieve(
			EPrints::Database::table_name( "subscription" ),
			[ "subid" ],
			[ "subid LIKE \"$id\"" ] );
		
		if( $#{$rows}==-1 )
		{
			$found = 1;
		}
		else
		{
			$cand++;
		}
	}
	
	return( $id );
}


######################################################################
#
# $success = remove()
#
#  Remove the subscription.
#
######################################################################

## WP1: BAD
sub remove
{
	my( $self ) = @_;
	
	return( $self->{session}->{database}->remove(
		EPrints::Database::table_name( "subscription" ),
		"subid",
		$self->{subid} ) );
}


######################################################################
#
# $html = render_subscription_form()
#
#  Render a form for this subscription. Doesn't render any buttons.
#
######################################################################

## WP1: BAD
sub render_subscription_form
{
	my( $self ) = @_;
	
	my $html = $self->{searchexpression}->render_search_form( 1, 0 );
	my @all_fields = $self->{session}->{metainfo}->get_fields( "subscription" );
	
	$html .= "<P>";
#cjg
	#$html .= $self->{session}}->phrase( "lib/subscription:sendupdates",
	           #{ howoften=>$self->{session}->{render}->input_field( 
		        #EPrints::MetaInfo::find_field( \@all_fields, "frequency" ),
		        #$self->{frequency} ) } );
	$html .= "</P>\n";
	
	return( $html );
}


######################################################################
#
# $problems = from_form()
#
#  Update the subscription from the form. Any problems returned as
#  text descriptions in an array.
#
######################################################################

## WP1: BAD
sub from_form
{
	my( $self ) = @_;
	
	my @all_fields = $self->{session}->{metainfo}->get_fields( "subscription" );
#cjg
	#$self->{frequency} = $self->{session}->{render}->form_value(
		 #EPrints::MetaInfo::find_field( \@all_fields, "frequency" ) );

	return( $self->{searchexpression}->from_form() );
}


######################################################################
#
# $success = commit()
#
#  Commit the changes from any web form etc. to the database.
#
######################################################################

## WP1: BAD
sub commit
{
	my( $self ) = @_;
	
	# Get the text rep of the search expression
	$self->{spec} = $self->{searchexpression}->to_string();

	return( $self->{session}->{database}->update(
		EPrints::Database::table_name( "subscription" ),
		$self ) );
}
	

######################################################################
#
# @subscriptions = subscriptions_for( $session, $user )
#
#  Find subscriptions for the given user
#
######################################################################

## WP1: BAD
sub subscriptions_for
{
	my( $session, $user ) = @_;
	
	my @subscriptions;
	
	my @sub_fields = $session->{metainfo}->get_fields( "subscription" );

	my $rows = $session->{database}->retrieve_fields(
		EPrints::Database::table_name( "subscription" ),
		\@sub_fields,
		[ "username LIKE \"$user->{username}\"" ] );
	
	foreach (@$rows)
	{
		push @subscriptions, new EPrints::Subscription( $session, undef, $_ );
	}
	
	return( @subscriptions );
}


######################################################################
#
# @subscriptions = subscriptions_for_frequency( $session, $frequency )
#
#  Returns subscriptions for the given frequency (daily, weekly or
#  monthly).
#
######################################################################

## WP1: BAD
sub subscriptions_for_frequency
{
	my( $session, $frequency ) = @_;
	
	my @subscriptions;
	
	my @sub_fields = $session->{metainfo}->get_fields( "subscription" );

	my $rows = $session->{database}->retrieve_fields(
		EPrints::Database::table_name( "subscription" ),
		\@sub_fields,
		[ "frequency LIKE \"$frequency\"" ] );
	
	foreach (@$rows)
	{
		push @subscriptions, new EPrints::Subscription( $session, undef, $_ );
	}
	
	return( @subscriptions );
}
		

######################################################################
#
# @subscriptions = get_daily( $session )
#
#  Returns daily subscriptions.
#
######################################################################

## WP1: BAD
sub get_daily
{
	my( $session ) = @_;
	
	return( EPrints::Subscription::subscriptions_for_frequency( $session,
	                                                            "daily" ) );
}


######################################################################
#
# @subscriptions = get_weekly( $session )
#
#  Returns weekly subscriptions.
#
######################################################################

## WP1: BAD
sub get_weekly
{
	my( $session ) = @_;
	
	return( EPrints::Subscription::subscriptions_for_frequency( $session,
	                                                            "weekly" ) );
}


######################################################################
#
# @subscriptions = get_monthly( $session )
#
#  Returns monthly subscriptions.
#
######################################################################

## WP1: BAD
sub get_monthly
{
	my( $session ) = @_;
	
	return( EPrints::Subscription::subscriptions_for_frequency( $session,
	                                                            "monthly" ) );
}


######################################################################
#
# $success = process()
#
#  Process the subscription. This will always result in a mail being
#  sent, and thus should only be invoked at appropriate intervals.
#
#  Daily subscriptions: everything dated yesterday will be sent.
#  Weekly: everything in the previous week (not including current day.)
#  Monthly: everything in the previous month (not including current day.)
#
#  Current day's submissions are not included, since more might be
#  received in the same day, so in the next processing, we won't know
#  which have been sent to the user and which haven't.
#
######################################################################

## WP1: BAD
sub process
{
	my( $self ) = @_;
	
	# Get the user
	my $user = new EPrints::User( $self->{session}, $self->{username} );
	
	unless( defined $user )
	{
		$self->{session}->get_site()->log( "Couldn't open user record for user ".$self->{username}." (sub ID ".$self->{subid}.")" );
		return( 0 );
	}

	# Get the search expression and frequency
	my $se = $self->{searchexpression};
	my $freq = $self->{frequency};
	$freq = "never" if( !defined $freq );

	# Get the datestamp field
	my $ds_field = $self->{session}->{metainfo}->find_table_field( "eprint", "datestamp" );

	# Get the date for yesterday
	my $yesterday = EPrints::MetaField::get_datestamp( time - (24*60*60) );

	# Update the search expression to search the relevant time period
	if( $freq eq "daily" )
	{
		# Get from the last day
#cjg?
		$se->add_field( $ds_field, $yesterday );
	}
	elsif( $freq eq "weekly" )
	{
		# Work out date a week ago
		my $last_week = EPrints::MetaField::get_datestamp( time - (7*24*60*60) );

		# Get from the last week
		$se->add_field( $ds_field, "$last_week-$yesterday" );
#cjg?
	}
	elsif( $freq eq "monthly" )
	{
		# Get today's date
		my( $year, $month, $day ) = EPrints::MetaField::get_date( time );
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
		
		# Add the field searching for stuff from a month ago to yesterday.
		$se->add_field( $ds_field, "$year-$month-$day-$yesterday" );
#cjg?
	}

	my $success = 0;
	
	# If the subscription is active, send it off
	unless( $freq eq "never" )
	{
		my @eprints = $se->do_eprint_search();
		
		# Don't send a mail if we've retrieved nothing
		return( 1 ) if( scalar @eprints == 0 );

		my $freqphrase = $self->{session}->phrase("lib/subscription:$freq");

		# Put together the body of the message. First some blurb:
		my $body = $self->{session}->phrase( 
			   "lib/subscription:blurb",
			   howoften=>$freqphrase,
			     sitename=>$self->{session}->{site}->{sitename},
			     url=>"$self->{session}->{site}->{server_perl}/users/subscribe" );
		
		# Then how many we got
		$body .= "                              ==========\n\n";
		$body .= "   ";
		if ( scalar @eprints==1 )
		{
			$body .= $self->{session}->phrase( "lib/subscription:newsub" ); 
		}
		else
		{
			$body .= $self->{session}->phrase( "lib/subscription:newsubs", 
			                                   n=>scalar @eprints ); 
		}
		$body .= "\n\n\n";
		
		# Then citations, with links to appropriate pages.
		foreach (@eprints)
		{
			$body .= $self->{session}->{render}->render_eprint_citation(
				$_, 0, 0 );
			$body .= "\n\n".$_->static_page_url()."\n\n\n";
		}
		
		# Send the mail.
		$success = EPrints::Mailer::send_mail( 
			$self->{session},
		             $user->full_name(),
		             $user->{email},
			     $self->{session}->phrase( "lib/subscription:subsubj" ),
		             $body );

		unless( $success )
		{
			$self->{session}->log( "Failed to send subscription to user ".$user->{username}.": $!" );
		}
	}
		
	return( $success );
}


1;
