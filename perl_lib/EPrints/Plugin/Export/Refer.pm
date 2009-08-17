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

	$data->{L} = $plugin->{handle}->get_repository->get_id . $dataobj->get_id;

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
				$out .= "%$k " . remove_utf8( $_ ) . "\n";
			}
		} else {
			$out .= "%$k " . remove_utf8( $data->{$k} ) . "\n";
		}
	}
	$out .= "\n";

	return $out;
}

sub remove_utf8
{
	my( $text, $char ) = @_;

	$char = '?' unless defined $char;

	$text = "" unless( defined $text );

	$text =~ s/[^\x00-\x80]/$char/g;

	return $text;
}

1;
