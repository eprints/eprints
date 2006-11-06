######################################################################
#
# EPrints::MetaField::Longtext;
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

B<EPrints::MetaField::Fulltext> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Fulltext;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Text );
}

use EPrints::MetaField::Text;

sub is_browsable
{
	return( 0 );
}

sub get_value
{
	my( $self, $object ) = @_;
	my @docs = $object->get_all_documents;
	my $r = [];
	foreach my $doc ( @docs )
	{
		push @{$r}, "_FULLTEXT_:".$doc->get_id;
	}
	return $r;
}

sub get_index_codes_basic
{
	my( $self, $session, $value ) = @_;

	if( $value !~ s/^_FULLTEXT_:// )
	{
		return $self->SUPER::get_index_codes_basic( $session, $value );
	}
	my $doc = EPrints::DataObj::Document->new( $session, $value );

	my $eprint =  $doc->get_eprint;
	return( [], [], [] ) unless( defined $eprint );

	my $words_file = $doc->words_file;
	my $indexcodes_file = $doc->indexcodes_file;
	my @s1 = stat( $words_file );
	my @s2 = stat( $indexcodes_file );
    	if( defined $s1[9] && defined $s2[9] && $s2[9] > $s1[9] )
	{
		my $codes = [];
		unless( open( CODELOG, $indexcodes_file ) )
		{
			$session->get_repository->log( "Failed to open $indexcodes_file: $!" );
		}
		else
		{
			@$codes = <CODELOG>;
			s/\015?\012?$//s for @$codes;
			close CODELOG;
		}
		return( $codes, [], [] );
	}

	$value = $doc->get_text;
	my( $codes, $badwords ) = ( [], [] );
	if( EPrints::Utils::is_set( $value ) )
	{
		( $codes, $badwords ) = EPrints::MetaField::Text::_extract_words( $session, $value );
	}
	
	unless( open( CODELOG, ">".$indexcodes_file ) )
	{
		$session->get_repository->log( "Failed to write to $indexcodes_file: $!" );
	}
	else
	{
		print CODELOG join( "\n", @$codes );
		close CODELOG;
	}
		
	# does not return badwords
	return( $codes, [], [] );
}


######################################################################
1;
