=head1 NAME

EPrints::Plugin::Export::Refer

=cut

package EPrints::Plugin::Export::Refer;

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Refer";
	$self->{accept} = [ 'list/eprint', 'dataobj/eprint' ];
	$self->{visible} = "all";
	$self->{suffix} = ".refer";
	$self->{mimetype} = "text/plain";

	return $self;
}


sub convert_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $data = {};

	if( $dataobj->exists_and_set( "creators" ) )
	{
		foreach my $name ( @{ $dataobj->get_value( "creators" ) } )
		{
			# given name first
			push @{ $data->{A} }, EPrints::Utils::make_name_string( $name->{name}, 1 );
		}
	}
	if( $dataobj->exists_and_set( "editors" ) )
	{
		foreach my $name ( @{ $dataobj->get_value( "editors" ) } )
		{
			# given name first
			push @{ $data->{E} }, EPrints::Utils::make_name_string( $name->{name}, 1 );
		}
	}

	$data->{T} = $dataobj->get_value( "title" ) if $dataobj->exists_and_set( "title" );
	#??$data->{B} = $dataobj->get_value( "event_title" ) if $dataobj->exists_and_set( "event_title" );
	$data->{B} = $dataobj->get_value( "book_title" ) if $dataobj->exists_and_set( "book_title" );

	if( $dataobj->exists_and_set( "date" ) )
	{
		$dataobj->get_value( "date" ) =~ /^([0-9]{4})/;
		$data->{D} = $1;
	}

	$data->{J} = $dataobj->get_value( "publication" ) if $dataobj->exists_and_set( "publication" );
	$data->{V} = $dataobj->get_value( "volume" ) if $dataobj->exists_and_set( "volume" ) && $dataobj->get_type ne "patent";
	$data->{N} = $dataobj->get_value( "number" ) if $dataobj->exists_and_set( "number" ) && $dataobj->get_type ne "patent";
	$data->{S} = $dataobj->get_value( "series" ) if $dataobj->exists_and_set( "series" );
	
	if( $dataobj->get_type eq "book" || $dataobj->get_type eq "thesis" )
	{
		
	}

	$data->{P} = $dataobj->get_value( "pagerange" ) if $dataobj->exists_and_set( "pagerange" );
	$data->{R} = $dataobj->get_value( "id_number" ) if $dataobj->exists_and_set( "id_number" );

	$data->{I} = $dataobj->get_value( "institution" ) if $dataobj->exists_and_set( "institution" );
	$data->{I} = $dataobj->get_value( "publisher" ) if $dataobj->exists_and_set( "publisher" );
	$data->{C} = $dataobj->get_value( "event_location" ) if $dataobj->exists_and_set( "event_location" );
	$data->{C} = $dataobj->get_value( "place_of_pub" ) if $dataobj->exists_and_set( "place_of_pub" );

	$data->{O} = $dataobj->get_value( "note" ) if $dataobj->exists_and_set( "note" );
	$data->{K} = $dataobj->get_value( "keywords" ) if $dataobj->exists_and_set( "keywords" );
	$data->{X} = $dataobj->get_value( "abstract" ) if $dataobj->exists_and_set( "abstract" );

	$data->{L} = $plugin->{session}->get_repository->get_id . $dataobj->get_id;

	return $data;
}

# The programs that print entries understand most nroff and
# troff  conventions (e.g. for bold face, greek characters,
#  etc.).  In particular, for names that include  spaces  in
#  them (e.g. `Louis des Tombe', where `des' and `Tombe' are
#  effectively one word) use the `\0' for the space,  as  in
#  `Louis des\0Tombe'. For Special Characters, put \*X after
#  a normal character (X is  normally  something  that  will
#  overprint  the  normal character for the desired effect).
#  Here is a list:
#   e'(e-acute: e \ * apostrophe ')
#   e`(e-grave: e \ * open single quote `)
#   a^(a-circumflex: a \ * circumflex ^)
#   a"(a-umlaut: a \ * colon :)
#   c,(c-cidilla: c \ * comma ,)
#   a~(a-tilde: a \ * tilde ~)

sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $data = $plugin->convert_dataobj( $dataobj );

	my $out;
	foreach my $k ( keys %{ $data } )
	{
		if( ref( $data->{$k} ) eq "ARRAY" )
		{
			foreach( @{ $data->{$k} } )
			{
				$out .= "%$k " . encode_str( $_ ) . "\n";
			}
		} else {
			$out .= "%$k " . encode_str( $data->{$k} ) . "\n";
		}
	}
	$out .= "\n";

	return $out;
}

sub encode_str
{
        my( $text, $char ) = @_;

        return "" unless defined $text;

        #$text = Encode::encode("iso-8859-1", $text, Encode::FB_DEFAULT);
        $text = Encode::encode("utf-8", $text, Encode::FB_DEFAULT);

        return $text;
}



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

