######################################################################
#
#  EPrints Citation Tools
#
#   A set of utility methods for easy rendering of citations
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

package EPrints::Citation;

use EPrints::MetaField;
use EPrints::MetaInfo;
use EPrints::Session;
use EPrints::Language;

use strict;


######################################################################
#
# $html = render_citation( $session, $citation_spec, $value_hash, $html )
#
#  [STATIC]
#  Renders a citation using the values in $value_hash. HTML formatting
#  will be removed if $html is zero.
#
#  $citation_spec specifies how the citation should be formatted.
#
#  "{value}"          will be replaced by the field $value_hash->{value}
#  "[volume {volume}] will be replaced by "volume ".$value_hash->{volume}
#                     unless $value_hash->{volume} is undefined or an empty
#                     string, in which case it will be replaced with nothing.
#
#  Everything else is left as-is.
#
######################################################################

sub render_citation
{
	my( $session, $citation_spec, $value_hash, $html ) = @_;
	
	my $citation = $citation_spec;

	# First handle the fields with dependent text [volume {value}]

	# Get out everything between the brackets
	while( $citation =~ /\[([^\]]+)\]/ )
	{
		my $entry = $1;

		# Get the fieldname and MetaField entry
		$entry =~ /{([^}]+)}/;
		my $fieldname = $1;

		my $field = $session->{metainfo}->find_eprint_field( $fieldname );

		# Check we have it
		if( defined $field )
		{
			# Get the value out of thehash
			my $value = $value_hash->{$fieldname};

			if( defined $value && $value ne "" )
			{
				# If it's not null or an empty string, go ahead with the
				# substitution
				my $rendered = _remove_problematic( 
					$session->{render}->format_field( $field, $value ) );
				my $new_entry = $entry;
				$new_entry =~ s/{$fieldname}/$rendered/;
				substr( $citation,
				        (index $citation, "[$entry]"),
				        length "[$entry]" ) = $new_entry;
			}
			else
			{
				# Remove the entry
				substr( $citation,
				        (index $citation, "[$entry]"),
				        length "[$entry]" ) = "";

				#$citation =~ s/\[$entry\]//;
			}
		}
		else
		{
			EPrints::Log::log_entry(
				"L:unknowneprint",
				{ fieldname=>$fieldname,
				  citation_spec=>$citation_spec } );
			return( $session->{lang}->phrase( "A:na" ) );
		}
	}

	# Put any square brackets back
	
	# Now sort out the fields on their own {value}
	while( $citation =~ /{([^}]+)}/ )
	{
		my $entry = $1;
		my $field = $session->{metainfo}->find_eprint_field( $entry );

		# Check we have it
		if( defined $field )
		{
			# Get the value out of thehash
			my $value = $value_hash->{$entry};

			if( defined $value && $value ne "" )
			{
				# If it's not null or an empty string, go ahead with the
				# substitution
				my $rendered = _remove_problematic(
					$session->{render}->format_field( $field, $value ) );
				$citation =~ s/\{$entry\}/$rendered/;
			}
			else
			{
				# Remove the entry
				$citation =~ s/\{$entry\}//;
			}
		}
		else
		{
			EPrints::Log::log_entry(
				"L:unknowneprint",
				{ fieldname=>$entry,
				   citation_spec=>$citation_spec } );
		}
	}
	
	# Remove HTML formatting if not HTML
	unless( $html )
	{
		$citation =~ s/<[^>]+>//g;
	}
	
	return( $citation );
}



######################################################################
#
# $new = _remove_problematic( $old )
#
#  Changes []'s and {}'s into brackets so as not to interfere with
#  later substitutions in the citation.
#
######################################################################

sub _remove_problematic
{
	my $old = shift;

	$old =~ s/[\[{]/(/g;	
	$old =~ s/[\]}]/)/g;	
	
	return( $old );
}

1;
