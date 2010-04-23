package EPrints::Plugin::Issues;

use strict;

our @ISA = qw/ EPrints::Plugin /;

$EPrints::Plugin::Issues::DISABLE = 1;

sub matches 
{
	my( $self, $test, $param ) = @_;

	if( $test eq "is_available" )
	{
		return( $self->is_available() );
	}

	# didn't understand this match 
	return $self->SUPER::matches( $test, $param );
}

sub is_available
{
	my( $self ) = @_;

	return 1;
}

# return all issues on this set, as a hash keyed on eprintid.
sub list_issues
{
	my( $plugin, %opts ) = @_;

	my $info = { issues => {}, opts=>\%opts };
	$opts{list}->map( 
		sub { 
			my( $session, $dataset, $item, $info ) = @_;
			my @issues = $plugin->process_item_in_list( $item, $info );
		},
		$info
	);
	$plugin->process_at_end( $info );

	return $info->{issues};
}

# This is used to add any additional issues based on cumulative information
sub process_at_end
{
	my( $plugin, $info ) = @_;

	# nothing by default
}

# info is the data block being used to store cumulative information for
# processing at the end.
sub process_item_in_list
{
	my( $plugin, $item, $info ) = @_;

	my @issues = $plugin->item_issues( $item );
	foreach my $issue ( @issues )
	{
		push @{$info->{issues}->{$item->get_id}}, $issue;
	}
}


# return an array of issues. Issues should be of the type
# { description=>XHTMLDOM, type=>string }
# if one item can have multiple occurances of the same issue type then add
# an id field too. This only need to be unique within the item.
sub item_issues
{
	my( $plugin, $dataobj ) = @_;
	
	return ();
}

1;
