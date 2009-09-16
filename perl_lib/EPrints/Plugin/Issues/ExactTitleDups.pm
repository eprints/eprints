package EPrints::Plugin::Issues::ExactTitleDups;

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Issues" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Exact title duplicates";

	return $self;
}

sub process_at_end
{
	my( $plugin, $info ) = @_;

	my $session = $plugin->{session};
	foreach my $code ( keys %{$info->{titlemap}} )
	{
		my @set = @{$info->{titlemap}->{$code}};
		next unless scalar @set > 1;
		foreach my $id ( @set )
		{
			my $eprint = EPrints::DataObj::EPrint->new( $session, $id );
			my $desc = $session->make_doc_fragment;
			$desc->appendChild( $session->make_text( "Duplicate title to " ) );
			$desc->appendChild( $eprint->render_citation_link_staff );
			OTHER: foreach my $id2 ( @set )
			{
				next OTHER if $id == $id2;
				push @{$info->{issues}->{$id2}}, {
					type => "duplicate_title",
					id => "duplicate_title_$id",
					description => $desc,
				};
			}
		}
	}
}

# info is the data block being used to store cumulative information for
# processing at the end.
sub process_item_in_list
{
	my( $plugin, $item, $info ) = @_;

	my $title = $item->get_value( "title" );
	return if !defined $title;

	push @{$info->{titlemap}->{$title}}, $item->get_id;
}



1;


