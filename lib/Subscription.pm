######################################################################
#
#  EPrints Subscription Class
#
#   Holds information about a user subscription.
#
######################################################################
#
#  03/04/2000 - Created by Robert Tansley
#
######################################################################

package EPrints::Subscription;

use EPrints::Database;
use EPrints::MetaInfo;
use EPrints::User;


@EPrints::Subscription::system_meta_fields =
(
	"subid:text::Subscription ID:1:0:0",
	"username:text::User:1:0:0:1",
	"spec:text::Specification:1:0:0",
	"frequency:enum:daily,Daily;weekly,Weekly;monthly,Monthly:Frequency:1:1:1"
);



######################################################################
#
# $subscription = new( $session, $subid, $dbrow )
#
#  Retrieve a subscription from the database. $row can be the row
#  for the subscription if it's been retrieved already.
#
######################################################################

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
			$EPrints::Database::table_subscription,
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
	my @fields = EPrints::MetaInfo->get_subscription_fields();

	my $i=0;
	
	foreach (@fields)
	{
		$self->{$_->{name}} = $dbrow->[$i];
		$i++;
	}

	my @metafields = EPrints::SearchExpression->make_meta_fields(
		"eprints",
		\@EPrintSite::SiteInfo::subscription_fields );

	# Get out the search expression
	$self->{searchexpression} = new EPrints::SearchExpression(
		$self->{session},
		$EPrints::Database::table_archive;
		1,
		\@metafields,
		\%EPrintSite::SiteInfo::eprint_order_methods,
		$EPrintSite::SiteInfo::default_eprint_order );

	$self->{searchexpression}->state_from_string( $self->{spec} )
		if( defined $self->{spec} && $spec ne "" );

	return( $self );
}


######################################################################
#
# $subscription = create( $session, $username )
#
#  Create a new subscription for the given user.
#
######################################################################

sub create
{
	my( $class, $session, $username ) = @_;
	
	my $self = {};
	bless $self, $class;

	$self->{session} = $session;

	my $id = _generate_subid( $session, $username );
	
	$self->{subid} = $id;
	$self->{username} = $username;
	
	$session->{database}->add_record( $EPrints::Database::table_subscription,
	                                  [ [ "subid", $self->{subid} ],
	                                    [ "username", $username ] ] );
	
	return( new EPrints::Subscription( $session, $id ) );
}


######################################################################
#
# $id = _generate_id( $session, $username )
#
#  Generate an ID for a new subscription
#
######################################################################

sub _generate_id
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
			$EPrints::Database::table_subscription,
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

sub remove
{
	my( $self ) = @_;
	
	return( $self->{session}->{database}->remove(
		$EPrints::Database::table_subscription,
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

sub render_subscription_form
{
	my( $self ) = @_;
	
	my $html = $self->{searchexp}->render_search_form( 1 ) );
	my @all_fields = EPrints::MetaInfo->get_subscription_fields;
	
	$html .= "<CENTER><P>Send updates: ";
	$html .= $self->{session}->{render}->input_field( 
		EPrints::MetaInfo->find_field( \@all_fields, "frequency" ),
		$self->{frequency} );
	$html .= "</P></CENTER>\n";
	
	return( $html );
}


######################################################################
#
# @problems = from_form()
#
#  Update the subscription from the form. Any problems returned as
#  text descriptions in an array.
#
######################################################################

sub from_form
{
	my( $self ) = @_;
	
	my @all_fields = EPrints::MetaInfo->get_subscription_fields;
	$self->{frequency} = $self->{session}->{render}->form_value(
		 EPrints::MetaInfo->find_field( \@all_fields, "frequency" ) );

	return( $self->{searchexp}->from_form() );
}


######################################################################
#
# $success = commit()
#
#  Commit the changes from any web form etc. to the database.
#
######################################################################

sub commit
{
	my( $self ) = @_;
	
	# Get the text rep of the search expression
	$self->{spec} = $self->{searchexpression}->to_string();

	my @all_fields = EPrints::MetaInfo->get_subscription_fields();
	
	my $key_field = shift @all_fields;
	my @data;
	
	foreach (@all_fields)
	{
		push @data, [ $_->{name}, $self->{$_->{name}} ];
	}
	
	return( $self->{session}->{database}->update(
		$EPrints::Database::table_subscription,
		$key_field->{name};
		$self->{$key_field->{name}},
		\@data ) );
}
	


1;
