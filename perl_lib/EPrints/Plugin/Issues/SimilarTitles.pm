package EPrints::Plugin::Issues::SimilarTitles;

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Issues" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Similar titles";

	return $self;
}

sub process_at_end
{
	my( $plugin, $info ) = @_;

	my $session = $plugin->{session};
	foreach my $code ( keys %{$info->{codemap}} )
	{
		my @set = @{$info->{codemap}->{$code}};
		next unless scalar @set > 1;
		foreach my $id ( @set )
		{
			my $eprint = EPrints::DataObj::EPrint->new( $session, $id );
			my $desc = $session->make_doc_fragment;
			$desc->appendChild( $session->make_text( "Similar title to " ) );
			$desc->appendChild( $eprint->render_citation_link_staff );
			OTHER: foreach my $id2 ( @set )
			{
				next OTHER if $id == $id2;
				# next if either of these have no title
				next OTHER if !EPrints::Utils::is_set( $info->{id_to_title}->{$id} );
				next OTHER if !EPrints::Utils::is_set( $info->{id_to_title}->{$id2} );
				# Don't match exact title matches
				next OTHER if $info->{id_to_title}->{$id} eq $info->{id_to_title}->{$id2};
				push @{$info->{issues}->{$id2}}, {
					type => "similar_title",
					id => "similar_title_$id",
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
	return if !EPrints::Utils::is_set( $title );

	$info->{id_to_title}->{$item->get_id} = $title;
	push @{$info->{codemap}->{make_code( $title )}}, $item->get_id;
}

sub make_code
{
	my( $string ) = @_;

	# Lowercase string
	$string = "\L$string";

	# remove one and two character words
	$string =~ s/\b[a-z][a-z]?\b//g; 

	# turn one-or more non-alphanumerics into a single space.
	$string =~ s/[^a-z0-9]+/ /g;

	# remove leading and ending spaces
	$string =~ s/^ //;
	$string =~ s/ $//;

	# remove double characters
	$string =~ s/([^ ])\1/$1/g;

	# remove vowels 
	$string =~ s/[aeiou]//g;

	return $string;
}



1;


