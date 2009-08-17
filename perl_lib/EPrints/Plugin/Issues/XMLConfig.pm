package EPrints::Plugin::Issues::XMLConfig;

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Issues" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Issues XML Config File";

	return $self;
}

sub config_file
{
	my( $plugin ) = @_;

	return $plugin->{handle}->get_repository->get_conf( "config_path" )."/issues.xml";
}

sub get_config
{
	my( $plugin ) = @_;

	if( !defined $plugin->{issuesconfig} )
	{
		my $file = $plugin->config_file;
		my $doc = $plugin->{handle}->get_repository->parse_xml( $file , 1 );
		if( !defined $doc )
		{
			$plugin->{handle}->get_repository->log( "Error parsing $file\n" );
			return;
		}
	
		$plugin->{issuesconfig} = ($doc->getElementsByTagName( "issues" ))[0];
		if( !defined $plugin->{issuesconfig} )
		{
			$plugin->{handle}->get_repository->log(  "Missing <issues> tag in $file\n" );
			EPrints::XML::dispose( $doc );
			return;
		}
	}
	
	return $plugin->{issuesconfig};
}

sub is_available
{
	my( $plugin ) = @_;

	return( -e $plugin->config_file );
}

# return an array of issues. Issues should be of the type
# { description=>XHTML String, type=>string }
# if one item can have multiple occurances of the same issue type then add
# an id field too. This only need to be unique within the item.
sub item_issues
{
	my( $plugin, $dataobj ) = @_;
	
	my %params = ();
	$params{item} = $dataobj;
	$params{current_user} = $plugin->{handle}->current_user;
	$params{handle} = $plugin->{handle};
	my $issues = EPrints::XML::EPC::process( $plugin->get_config, %params );

	my @issues_list = ();
	foreach my $child ( $issues->getChildNodes )
	{
		next unless( $child->nodeName eq "issue" );
		my $issue = {};
		$issue->{description} = EPrints::XML::contents_of( $child );
		$issue->{type} = $child->getAttribute( "type" );
		$issue->{id} = $child->getAttribute( "issue_id" );
		push @issues_list, $issue;
	}

	return @issues_list;
}

1;


