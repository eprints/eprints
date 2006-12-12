=pod

=head1 FILE FORMAT

See L<EPrints::Plugin::Import::BibTeX>

=cut

package EPrints::Plugin::Export::BibTeX;

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use Unicode::String qw(latin1);

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{name} = "BibTeX";
	$self->{accept} = [ 'list/eprint', 'dataobj/eprint' ];
	$self->{visible} = "all";
	$self->{suffix} = ".bib";
	$self->{mimetype} = "text/plain";

	return $self;
}

sub convert_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $data = ();

	# Key
	$data->{key} = $plugin->{session}->get_repository->get_id . $dataobj->get_id;

	# Entry Type
	my $type = $dataobj->get_type;
	$data->{type} = "misc";
	$data->{type} = "article" if $type eq "article";
	$data->{type} = "book" if $type eq "book";
	$data->{type} = "incollection" if $type eq "book_section";
	$data->{type} = "inproceedings" if $type eq "conference_item";
	if( $type eq "monograph" )
	{
		if( $dataobj->exists_and_set( "monograph_type" ) &&
			( $dataobj->get_value( "monograph_type" ) eq "manual" ||
			$dataobj->get_value( "monograph_type" ) eq "documentation" ) )
		{
			$data->{type} = "manual";
		}
		else
		{
			$data->{type} = "techreport";
		}
	}
	if( $type eq "thesis")
	{
		if( $dataobj->exists_and_set( "thesis_type" ) && $dataobj->get_value( "thesis_type" ) eq "masters" )
		{
			$data->{type} = "mastersthesis";
		}
		else
		{
			$data->{type} = "phdthesis";	
		}
	}
	if( $dataobj->exists_and_set( "ispublished" ) )
	{
		$data->{type} = "unpublished" if $dataobj->get_value( "ispublished" ) eq "unpub";
	}

	# address
	$data->{bibtex}->{address} = $dataobj->get_value( "place_of_pub" ) if $dataobj->exists_and_set( "place_of_pub" );

	# author
	if( $dataobj->exists_and_set( "creators" ) )
	{
		my $names = $dataobj->get_value( "creators" );	
		$data->{bibtex}->{author} = join( " and ", map { EPrints::Utils::make_name_string( $_->{name}, 1 ) } @$names );
	}
	
	# booktitle
	$data->{bibtex}->{booktitle} = $dataobj->get_value( "event_title" ) if $dataobj->exists_and_set( "event_title" );
	$data->{bibtex}->{booktitle} = $dataobj->get_value( "book_title" ) if $dataobj->exists_and_set( "book_title" );

	# editor
	if( $dataobj->exists_and_set( "editors" ) )
	{
		my $names = $dataobj->get_value( "editors" );	
		$data->{bibtex}->{editor} = join( " and ", map { EPrints::Utils::make_name_string( $_->{name}, 1 ) } @$names );
	}

	# institution
	if( $type eq "monograph" && $data->{type} ne "manual" )
	{
		$data->{bibtex}->{institution} = $dataobj->get_value( "institution" ) if $dataobj->exists_and_set( "institution" );
	}

	# journal
	$data->{bibtex}->{journal} = $dataobj->get_value( "publication" ) if $dataobj->exists_and_set( "publication" );

	# month
	if ($dataobj->exists_and_set( "date" )) {
		$dataobj->get_value( "date" ) =~ /^[0-9]{4}-([0-9]{2})/;
		$data->{bibtex}->{month} = EPrints::Time::get_month_label( $plugin->{session}, $1 ) if $1;
	}

	# note	
	$data->{bibtex}->{note}	= $dataobj->get_value( "note" ) if $dataobj->exists_and_set( "note" );

	# number
	if( $type eq "monograph" )
	{
		$data->{bibtex}->{number} = $dataobj->get_value( "id_number" ) if $dataobj->exists_and_set( "id_number" );
	}
	else
	{
		$data->{bibtex}->{number} = $dataobj->get_value( "number" ) if $dataobj->exists_and_set( "number" );
	}

	# organization
	if( $data->{type} eq "manual" )
	{
		$data->{bibtex}->{organization} = $dataobj->get_value( "institution" ) if $dataobj->exists_and_set( "institution" );
	}

	# pages
	if( $dataobj->exists_and_set( "pagerange" ) )
	{	
		$data->{bibtex}->{pages} = $dataobj->get_value( "pagerange" );
		$data->{bibtex}->{pages} =~ s/-/--/;
	}

	# publisher
	$data->{bibtex}->{publisher} = $dataobj->get_value( "publisher" ) if $dataobj->exists_and_set( "publisher" );

	# school
	if( $type eq "thesis" )
	{
		$data->{bibtex}->{school} = $dataobj->get_value( "institution" ) if $dataobj->exists_and_set( "institution" );
	}

	# series
	$data->{bibtex}->{series} = $dataobj->get_value( "series" ) if $dataobj->exists_and_set( "series" );

	# title
	$data->{bibtex}->{title} = $dataobj->get_value( "title" ) if $dataobj->exists_and_set( "title" );

	# type
	if( $type eq "monograph" && $dataobj->exists_and_set( "monograph_type" ) )
	{
		$data->{bibtex}->{type} = EPrints::Utils::tree_to_utf8( $dataobj->render_value( "monograph_type" ) );
	}

	# volume
	$data->{bibtex}->{volume} = $dataobj->get_value( "volume" ) if $dataobj->exists_and_set( "volume" );

	# year
	if ($dataobj->exists_and_set( "date" )) {
		$dataobj->get_value( "date" ) =~ /^([0-9]{4})/;
		$data->{bibtex}->{year} = $1 if $1;
	}

	# Not part of BibTeX
	$data->{additional}->{abstract} = $dataobj->get_value( "abstract" ) if $dataobj->exists_and_set( "abstract" );
	$data->{additional}->{url} = $dataobj->get_url(); 
	$data->{additional}->{keywords} = $dataobj->get_value( "keywords" ) if $dataobj->exists_and_set( "keywords" );

	return $data;
}

sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $data = $plugin->convert_dataobj( $dataobj );

	my @list = ();
	foreach my $k ( keys %{$data->{bibtex}} )
	{
		push @list, sprintf( "%16s = {%s}", $k, utf8_to_tex( $data->{bibtex}->{$k} ));
	}
	foreach my $k ( keys %{$data->{additional}} )
	{
		push @list, sprintf( "%16s = {%s}", $k, remove_utf8( $data->{additional}->{$k} ));
	}

	my $out = '@' . $data->{type} . "{" . $data->{key} . ",\n";
	$out .= join( ",\n", @list ) . "\n";
	$out .= "}\n\n";

	return $out;
}


sub remove_utf8
{
	my( $text, $char ) = @_;

	$char = '?' unless defined $char;

	$text = "" unless( defined $text );

	my $stringobj = Unicode::String->new();
	$stringobj->utf8( $text );
	my $escstr = "";

	foreach($stringobj->unpack())
	{
		if( $_ < 128)
		{
			$escstr .= chr( $_ );
		}
		else
		{
			$escstr .= $char;
		}
	}

	return $escstr;
}



sub utf8_to_tex
{
	my( $text ) = @_;

	$text = "" unless( defined $text );
	
	my $stringobj = Unicode::String->new();
	$stringobj->utf8( $text );
	my $bibstr = "";

	foreach($stringobj->unpack())
	{
		#       print "$_: ".$EPrints::unimap->{$_}."\n";
		my $char_in_tex = $EPrints::unimap->{$_};
		if( defined $char_in_tex )
		{
			$bibstr .= $EPrints::unimap->{$_};
		}
		else
		{
			$bibstr .= '?';
		}
	}

	return $bibstr;
}



$EPrints::unimap = {
0x0009 => "\t",
0x000A => "\n",
0x000D => "\r",
0x0020 => ' ',
0x0021 => '!',
0x0022 => '"',
0x0023 => '\\',
0x0024 => '\\$',
0x0025 => '\\%',
0x0026 => '\\&',
0x0027 => '\'',
0x0028 => '(',
0x0029 => ')',
0x002A => '*',
0x002B => '+',
0x002C => ',',
0x002D => '-',
0x002E => '.',
0x002F => '/',
0x0030 => '0',
0x0031 => '1',
0x0032 => '2',
0x0033 => '3',
0x0034 => '4',
0x0035 => '5',
0x0036 => '6',
0x0037 => '7',
0x0038 => '8',
0x0039 => '9',
0x003A => ':',
0x003B => ';',
0x003C => '<',
0x003D => '=',
0x003E => '>',
0x003F => '?',
0x0040 => '@',
0x0041 => 'A',
0x0042 => 'B',
0x0043 => 'C',
0x0044 => 'D',
0x0045 => 'E',
0x0046 => 'F',
0x0047 => 'G',
0x0048 => 'H',
0x0049 => 'I',
0x004A => 'J',
0x004B => 'K',
0x004C => 'L',
0x004D => 'M',
0x004E => 'N',
0x004F => 'O',
0x0050 => 'P',
0x0051 => 'Q',
0x0052 => 'R',
0x0053 => 'S',
0x0054 => 'T',
0x0055 => 'U',
0x0056 => 'V',
0x0057 => 'W',
0x0058 => 'X',
0x0059 => 'Y',
0x005A => 'Z',
0x005B => '[',
0x005C => '$\backslash$',
0x005D => ']',
0x005E => '\verb1^1',
0x005F => '\verb1_1',
0x0060 => '`',
0x0061 => 'a',
0x0062 => 'b',
0x0063 => 'c',
0x0064 => 'd',
0x0065 => 'e',
0x0066 => 'f',
0x0067 => 'g',
0x0068 => 'h',
0x0069 => 'i',
0x006A => 'j',
0x006B => 'k',
0x006C => 'l',
0x006D => 'm',
0x006E => 'n',
0x006F => 'o',
0x0070 => 'p',
0x0071 => 'q',
0x0072 => 'r',
0x0073 => 's',
0x0074 => 't',
0x0075 => 'u',
0x0076 => 'v',
0x0077 => 'w',
0x0078 => 'x',
0x0079 => 'y',
0x007A => 'z',
0x007B => '\verb1{1',
0x007C => '\verb1|1',
0x007D => '\verb1}1',
0x007E => '\\verb1~1',
0x00A0 => '~',
0x00A3 => '\\pounds',
0x00A7 => '\\S',
0x00A8 => '\\"{\\empty}',
0x00A9 => '\\copyright',
0x00AC => '$\\lnot$',
0x00AD => '\\-',
0x00B1 => '$\\pm$',
0x00B2 => '$^2$',
0x00B3 => '$^3$',
0x00B5 => '$\\mu$',
0x00B6 => '\\P',
0x00B8 => '\\c\\space',
0x00B9 => '$^1$',
0x00C0 => '\\`A',
0x00C1 => '\\\'A',
0x00C2 => '\\^A',
0x00C3 => '\\~A',
0x00C4 => '\\"A',
0x00C5 => '\\r A',
0x00C6 => '\\AE',
0x00C7 => '\\c C',
0x00C8 => '\\`E',
0x00C9 => '\\\'E',
0x00CA => '\\^E',
0x00CB => '\\"E',
0x00CC => '\\`I',
0x00CD => '\\\'I',
0x00CE => '\\^I',
0x00CF => '\\"I',
0x00D1 => '\\~N',
0x00D2 => '\\`O',
0x00D3 => '\\\'O',
0x00D4 => '\\^O',
0x00D5 => '\\~O',
0x00D6 => '\\"O',
0x00D7 => '$\\times$',
0x00D8 => '\\O',
0x00D9 => '\\`U',
0x00DA => '\\\'U',
0x00DB => '\\^U',
0x00DC => '\\"U',
0x00DD => '\\\'Y',
0x00DF => '\\ss',
0x00E0 => '\\`a',
0x00E1 => '\\\'a',
0x00E2 => '\\^a',
0x00E3 => '\\~a',
0x00E4 => '\\"a',
0x00E5 => '\\r a',
0x00E6 => '\\ae',
0x00E7 => '\\c c',
0x00E8 => '\\`e',
0x00E9 => '\\\'e',
0x00EA => '\\^e',
0x00EB => '\\"e',
0x00EC => '\\`\\i',
0x00ED => '\\\'\\i',
0x00EE => '\\^\\i',
0x00EF => '\\"\\i',
0x00F1 => '\\~n',
0x00F2 => '\\`o',
0x00F3 => '\\\'o',
0x00F4 => '\\^o',
0x00F5 => '\\~o',
0x00F6 => '\\"o',
0x00F7 => '$\\div$',
0x00F8 => '\\o',
0x00F9 => '\\`u',
0x00FA => '\\\'u',
0x00FB => '\\^u',
0x00FC => '\\"u',
0x00FD => '\\\'y',
0x00FF => '\\"y',
0x0102 => '\\u A',
0x0103 => '\\u a',
0x0108 => '\\^C',
0x0109 => '\\^c',
0x010A => '\\.C',
0x010B => '\\.c',
0x010C => '\\v C',
0x010D => '\\v c',
0x010E => '\\v D',
0x010F => '\\v d',
0x0114 => '\\u E',
0x0115 => '\\u e',
0x0116 => '\\.E',
0x0117 => '\\.e',
0x011A => '\\v E',
0x011B => '\\v e',
0x011C => '\\^G',
0x011D => '\\^g',
0x011E => '\\u G',
0x011F => '\\u g',
0x0120 => '\\.G',
0x0121 => '\\.g',
0x0122 => '\\c G',
0x0124 => '\\^H',
0x0125 => '\\^h',
0x0128 => '\\~I',
0x0129 => '\\~\\i',
0x012C => '\\u I',
0x012D => '\\u\\i',
0x0130 => '\\.I',
0x0131 => '\\i',
0x0134 => '\\^J',
0x0135 => '\\^\\j',
0x0136 => '\\c K',
0x0137 => '\\c k',
0x013B => '\\c L',
0x013C => '\\c l',
0x013D => '\\v L',
0x013E => '\\v l',
0x0141 => '\\L',
0x0142 => '\\l',
0x0145 => '\\c N',
0x0146 => '\\c n',
0x0147 => '\\v N',
0x0148 => '\\v n',
0x014E => '\\u O',
0x014F => '\\u o',
0x0150 => '\\H O',
0x0151 => '\\H o',
0x0152 => '\\OE',
0x0153 => '\\oe',
0x0156 => '\\c R',
0x0157 => '\\c r',
0x0158 => '\\v R',
0x0159 => '\\v r',
0x015A => '\\\'S',
0x015B => '\\\'s',
0x015C => '\\^S',
0x015D => '\\^s',
0x015E => '\\c S',
0x015F => '\\c s',
0x0160 => '\\v S',
0x0161 => '\\v s',
0x0162 => '\\c T',
0x0163 => '\\c t',
0x0164 => '\\v T',
0x0165 => '\\v t',
0x0168 => '\\~U',
0x0169 => '\\~u',
0x016C => '\\u U',
0x016D => '\\u u',
0x016E => '\\r U',
0x016F => '\\r u',
0x0170 => '\\H U',
0x0171 => '\\H u',
0x0174 => '\\^W',
0x0175 => '\\^w',
0x0176 => '\\^Y',
0x0177 => '\\^y',
0x0178 => '\\"Y',
0x0179 => '\\\'Z',
0x017A => '\\\'z',
0x017B => '\\.Z',
0x017C => '\\.z',
0x017D => '\\v Z',
0x017E => '\\v z',
0x01CD => '\\v A',
0x01CE => '\\v a',
0x01CF => '\\v I',
0x01D0 => '\\v\\i',
0x01D1 => '\\v O',
0x01D2 => '\\v o',
0x01D3 => '\\v U',
0x01D4 => '\\v u',
0x01D9 => '\\v{\\"U}',
0x01DA => '\\v{\\"u}',
0x01E6 => '\\v G',
0x01E7 => '\\v g',
0x01E8 => '\\v K',
0x01E9 => '\\v k',
0x01F0 => '\\v\\j',
0x021E => '\\v H',
0x021F => '\\v h',
0x0226 => '\\.A',
0x0227 => '\\.a',
0x0228 => '\\c E',
0x0229 => '\\c e',
0x022E => '\\.O',
0x022F => '\\.o',
0x02C6 => '\\^{\\empty}',
0x02C7 => '\\v{\\empty}',
0x02CD => '\\b{\\empty}',
0x02D8 => '\\u{\\empty}',
0x02D9 => '\\.{\\empty}',
0x02DA => '\\r{\\empty}',
0x02DC => '\\~{\\empty}',
0x02DD => '\\H{\\empty}',
0x0391 => '$\\mathrm A$',
0x0392 => '$\\mathrm B$',
0x0393 => '$\\Gamma$',
0x0394 => '$\\Delta$',
0x0395 => '$\\mathrm E$',
0x0396 => '$\\mathrm Z$',
0x0397 => '$\\mathrm H$',
0x0398 => '$\\Theta$',
0x0399 => '$\\mathrm I$',
0x039A => '$\\mathrm K$',
0x039B => '$\\Lambda$',
0x039C => '$\\mathrm M$',
0x039D => '$\\mathrm N$',
0x039E => '$\\Xi$',
0x039F => '$\\mathrm O$',
0x03A0 => '$\\Pi$',
0x03A1 => '$\\mathrm P$',
0x03A3 => '$\\Sigma$',
0x03A4 => '$\\mathrm T$',
0x03A5 => '$\\Upsilon$',
0x03A6 => '$\\Phi$',
0x03A7 => '$\\mathrm X$',
0x03A8 => '$\\Psi$',
0x03A9 => '$\\Omega$',
0x03B1 => '$\\alpha$',
0x03B2 => '$\\beta$',
0x03B3 => '$\\gamma$',
0x03B4 => '$\\delta$',
0x03B5 => '$\\varepsilon$',
0x03B6 => '$\\zeta$',
0x03B7 => '$\\eta$',
0x03B8 => '$\\vartheta$',
0x03B9 => '$\\iota$',
0x03BA => '$\\kappa$',
0x03BB => '$\\lambda$',
0x03BC => '$\\mu$',
0x03BD => '$\\nu$',
0x03BE => '$\\xi$',
0x03BF => '$o$',
0x03C0 => '$\\pi$',
0x03C1 => '$\\varrho$',
0x03C2 => '$\\varsigma$',
0x03C3 => '$\\sigma$',
0x03C4 => '$\\tau$',
0x03C5 => '$\\upsilon$',
0x03C6 => '$\\varphi$',
0x03C7 => '$\\chi$',
0x03C8 => '$\\psi$',
0x03C9 => '$\\omega$',
0x05D0 => '$\\aleph$',
0x1E02 => '\\.B',
0x1E03 => '\\.b',
0x1E04 => '\\d B',
0x1E05 => '\\d b',
0x1E06 => '\\b B',
0x1E07 => '\\b b',
0x1E0A => '\\.D',
0x1E0B => '\\.d',
0x1E0C => '\\d D',
0x1E0D => '\\d d',
0x1E0E => '\\b D',
0x1E0F => '\\b d',
0x1E10 => '\\c D',
0x1E11 => '\\c d',
0x1E1E => '\\.F',
0x1E1F => '\\.f',
0x1E22 => '\\.H',
0x1E23 => '\\.h',
0x1E24 => '\\d H',
0x1E25 => '\\d h',
0x1E26 => '\\"H',
0x1E27 => '\\"h',
0x1E28 => '\\c H',
0x1E29 => '\\c h',
0x1E32 => '\\d K',
0x1E33 => '\\d k',
0x1E34 => '\\b K',
0x1E35 => '\\b k',
0x1E36 => '\\d L',
0x1E37 => '\\d l',
0x1E3A => '\\b L',
0x1E3B => '\\b l',
0x1E40 => '\\.M',
0x1E41 => '\\.m',
0x1E42 => '\\d M',
0x1E43 => '\\d m',
0x1E44 => '\\.N',
0x1E45 => '\\.n',
0x1E46 => '\\d N',
0x1E47 => '\\d n',
0x1E48 => '\\b N',
0x1E49 => '\\b n',
0x1E56 => '\\.P',
0x1E57 => '\\.p',
0x1E58 => '\\.R',
0x1E59 => '\\.r',
0x1E5A => '\\d R',
0x1E5B => '\\d r',
0x1E5E => '\\b R',
0x1E5F => '\\b r',
0x1E60 => '\\.S',
0x1E61 => '\\.s',
0x1E62 => '\\d S',
0x1E63 => '\\d s',
0x1E6A => '\\.T',
0x1E6B => '\\.t',
0x1E6C => '\\d T',
0x1E6D => '\\d t',
0x1E6E => '\\b T',
0x1E6F => '\\b t',
0x1E7C => '\\~V',
0x1E7D => '\\~v',
0x1E7E => '\\d V',
0x1E7F => '\\d v',
0x1E84 => '\\"W',
0x1E85 => '\\"w',
0x1E86 => '\\.W',
0x1E87 => '\\.w',
0x1E88 => '\\d W',
0x1E89 => '\\d w',
0x1E8A => '\\.X',
0x1E8B => '\\.x',
0x1E8C => '\\"X',
0x1E8D => '\\"x',
0x1E8E => '\\.Y',
0x1E8F => '\\.y',
0x1E90 => '\\^Z',
0x1E91 => '\\^z',
0x1E92 => '\\d Z',
0x1E93 => '\\d z',
0x1E94 => '\\b Z',
0x1E95 => '\\b z',
0x1E96 => '\\b h',
0x1E97 => '\\"t',
0x1E98 => '\\r w',
0x1E99 => '\\r y',
0x1EA0 => '\\d A',
0x1EA1 => '\\d a',
0x1EB8 => '\\d E',
0x1EB9 => '\\d e',
0x1EBC => '\\~E',
0x1EBD => '\\~e',
0x1ECA => '\\d I',
0x1ECB => '\\d i',
0x1ECC => '\\d O',
0x1ECD => '\\d o',
0x1EE4 => '\\d U',
0x1EE5 => '\\d u',
0x1EF4 => '\\d Y',
0x1EF5 => '\\d y',
0x1EF8 => '\\~Y',
0x1EF9 => '\\~y',
0x1FC0 => '\\~{\\empty}',
0x2000 => '\\enskip',
0x2001 => '\\quad',
0x2002 => '\\enskip',
0x2003 => '\\quad',
0x2004 => ' ',
0x2005 => ' ',
0x2006 => ' ',
0x2009 => '\\thinspace',
0x200B => '',
0x200C => '{}',
0x200D => '',
0x2014 => '--',
0x2018 => '`',
0x2019 => '\'',
0x201C => '``',
0x201D => '\'\'',
0x2020 => '\\dag',
0x2021 => '\\ddag',
0x2026 => '\\dots',
0x2032 => '$^\\prime$',
0x2033 => '$^{\\prime\\prime}$',
0x2034 => '$^{\\prime\\prime\\prime}$',
0x2070 => '$^0$',
0x2071 => '$^i$',
0x2074 => '$^4$',
0x2075 => '$^5$',
0x2076 => '$^6$',
0x2077 => '$^7$',
0x2078 => '$^8$',
0x2079 => '$^9$',
0x207A => '$^+$',
0x207B => '$^-$',
0x207C => '$^=$',
0x207D => '$^($',
0x207E => '$^)$',
0x207F => '$^n$',
0x2080 => '$_0$',
0x2081 => '$_1$',
0x2082 => '$_2$',
0x2083 => '$_3$',
0x2084 => '$_4$',
0x2085 => '$_5$',
0x2086 => '$_6$',
0x2087 => '$_7$',
0x2088 => '$_8$',
0x2089 => '$_9$',
0x208A => '$_+$',
0x208B => '$_-$',
0x208C => '$_=$',
0x208D => '$_($',
0x208E => '$_)$',
0x2102 => 'C',
0x210B => 'H',
0x210C => 'H',
0x210D => 'H',
0x210E => 'h',
0x210F => '$\\hbar$',
0x2110 => 'I',
0x2112 => 'L',
0x2115 => 'N',
0x2119 => 'P',
0x211A => 'Q',
0x211B => 'R',
0x211D => 'R',
0x2124 => 'Z',
0x2126 => '$\\Omega$',
0x2128 => 'Z',
0x212A => '$\\mathrm K$',
0x212C => 'B',
0x212D => 'C',
0x2130 => 'E',
0x2131 => 'F',
0x2133 => 'M',
0x2134 => 'o',
0x2135 => '$\\aleph$',
0x2191 => '$\\uparrow$',
0x2192 => '$\\rightarrow$',
0x2193 => '$\\downarrow$',
0x2194 => '\\ding{"D6}',
0x2194 => '$\\leftrightarrow$',
0x2195 => '\\ding{"D7}',
0x2195 => '$\\updownarrow$',
0x21CC => '$\\rightleftharpoons$',
0x21D2 => '$\\Rightarrow$',
0x21D4 => '$\\Leftrightarrow$',
0x2200 => '$\\forall$',
0x2202 => '$\\partial$',
0x2203 => '$\\exists$',
0x2204 => '$\\not\\exists$',
0x2205 => '$\\emptyset$',
0x2206 => '$\\Delta$',
0x2207 => '$\\nabla$',
0x2208 => '$\\in$',
0x2209 => '$\\notin$',
0x220B => '$\\ni$',
0x220C => '$\\not\\ni$',
0x220F => '$\\prod$',
0x2210 => '$\\coprod$',
0x2211 => '$\\sum$',
0x2212 => '$-$',
0x2213 => '$\\mp$',
0x2214 => '$\\dotplus$',
0x2215 => '$/$',
0x2216 => '$\\setminus$',
0x2217 => '$\\ast$',
0x2218 => '$\\circ$',
0x2219 => '$\\bullet$',
0x221A => '$\\surd$',
0x221D => '$\\propto$',
0x221E => '$\\infty$',
0x2220 => '$\\angle$',
0x2221 => '$\\measuredangle$',
0x2222 => '$\\sphericalangle$',
0x2223 => '$\\mid$',
0x2224 => '$\\nmid$',
0x2225 => '$\\parallel$',
0x2226 => '$\\nparallel$',
0x2227 => '$\\wedge$',
0x2228 => '$\\vee$',
0x2229 => '$\\cap$',
0x222A => '$\\cup$',
0x222B => '$\\int$',
0x222E => '$\\oint$',
0x2234 => '$\\therefore$',
0x2235 => '$\\because$',
0x223C => '$\\sim$',
0x223D => '$\\backsim$',
0x2240 => '$\\wr$',
0x2241 => '$\\nsim$',
0x2243 => '$\\simeq$',
0x2244 => '$\\not\\simeq$',
0x2245 => '$\\cong$',
0x2247 => '$\\ncong$',
0x2248 => '$\\approx$',
0x2249 => '$\\not\\approx$',
0x224A => '$\\approxeq$',
0x224D => '$\\asymp$',
0x224E => '$\\Bumpeq$',
0x224F => '$\\bumpeq$',
0x2250 => '$\\doteq$',
0x2251 => '$\\doteqdot$',
0x2252 => '$\\fallingdotseq$',
0x2253 => '$\\risingdotseq$',
0x2256 => '$\\eqcirc$',
0x2257 => '$\\circeq$',
0x225C => '$\\triangleq$',
0x2260 => '$\\neq$',
0x2261 => '$\\equiv$',
0x2262 => '$\\not\\equiv$',
0x2264 => '$\\leq$',
0x2265 => '$\\geq$',
0x2266 => '$\\leqq$',
0x2267 => '$\\geqq$',
0x2268 => '$\\lneqq$',
0x2269 => '$\\gneqq$',
0x226A => '$\\ll$',
0x226B => '$\\gg$',
0x226C => '$\\between$',
0x226D => '$\\not\\asymp$',
0x226E => '$\\nless$',
0x226F => '$\\ngtr$',
0x2270 => '$\\nleq$',
0x2271 => '$\\ngeq$',
0x2272 => '$\\lesssim$',
0x2273 => '$\\gtrsim$',
0x2274 => '$\\not\\lesssim$',
0x2275 => '$\\not\\gtrsim$',
0x2276 => '$\\lessgtr$',
0x2277 => '$\\gtrless$',
0x227A => '$\\prec$',
0x227B => '$\\succ$',
0x227C => '$\\preccurlyeq$',
0x227D => '$\\succcurlyeq$',
0x227E => '$\\precsim$',
0x227F => '$\\succsim$',
0x2280 => '$\\nprec$',
0x2281 => '$\\nsucc$',
0x2282 => '$\\subset$',
0x2283 => '$\\supset$',
0x2284 => '$\\not\\subset$',
0x2285 => '$\\not\\supset$',
0x2286 => '$\\subseteq$',
0x2287 => '$\\supseteq$',
0x2288 => '$\\nsubseteq$',
0x2289 => '$\\nsupseteq$',
0x228A => '$\\subsetneq$',
0x228B => '$\\supsetneq$',
0x228E => '$\\uplus$',
0x228F => '$\\sqsubset$',
0x2290 => '$\\sqsupset$',
0x2291 => '$\\sqsubseteq$',
0x2292 => '$\\sqsupseteq$',
0x2293 => '$\\sqcap$',
0x2294 => '$\\sqcup$',
0x2295 => '$\\oplus$',
0x2296 => '$\\ominus$',
0x2297 => '$\\otimes$',
0x2298 => '$\\oslash$',
0x2299 => '$\\odot$',
0x229A => '$\\circledcirc$',
0x229B => '$\\circledast$',
0x229D => '$\\circleddash$',
0x229E => '$\\boxplus$',
0x229F => '$\\boxminus$',
0x22A0 => '$\\boxtimes$',
0x22A1 => '$\\boxdot$',
0x22A2 => '$\\vdash$',
0x22A3 => '$\\dashv$',
0x22A4 => '$\\top$',
0x22A5 => '$\\bot$',
0x22A9 => '$\\Vdash$',
0x22AA => '$\\Vvdash$',
0x22AE => '$\\nVdash$',
0x22B2 => '$\\lhd$',
0x22B3 => '$\\rhd$',
0x22B4 => '$\\unlhd$',
0x22B5 => '$\\unrhd$',
0x22B8 => '$\\multimap$',
0x22BA => '$\\intercal$',
0x22BB => '$\\veebar$',
0x22BC => '$\\barwedge$',
0x22C0 => '$\\bigwedge$',
0x22C1 => '$\\bigvee$',
0x22C2 => '$\\bigcap$',
0x22C3 => '$\\bigcup$',
0x22C4 => '$\\diamond$',
0x22C5 => '$\\cdot$',
0x22C6 => '$\\star$',
0x22C7 => '$\\divideontimes$',
0x22C8 => '$\\bowtie$',
0x22C9 => '$\\ltimes$',
0x22CA => '$\\rtimes$',
0x22CB => '$\\leftthreetimes$',
0x22CC => '$\\rightthreetimes$',
0x22CD => '$\\backsimeq$',
0x22CE => '$\\curlyvee$',
0x22CF => '$\\curlywedge$',
0x22D0 => '$\\Subset$',
0x22D1 => '$\\Supset$',
0x22D2 => '$\\Cap$',
0x22D3 => '$\\Cup$',
0x22D4 => '$\\pitchfork$',
0x22D6 => '$\\lessdot$',
0x22D7 => '$\\gtrdot$',
0x22D8 => '$\\lll$',
0x22D9 => '$\\ggg$',
0x22DA => '$\\lesseqgtr$',
0x22DB => '$\\gtreqless$',
0x22DE => '$\\curlyeqprec$',
0x22DF => '$\\curlyeqsucc$',
0x22E6 => '$\\lnsim$',
0x22E7 => '$\\gnsim$',
0x22E8 => '$\\precnsim$',
0x22E9 => '$\\succnsim$',
0x22EA => '$\\ntriangleleft$',
0x22EB => '$\\ntriangleright$',
0x22EC => '$\\ntrianglelefteq$',
0x22ED => '$\\ntrianglerighteq$',
0x22EE => '$\\vdots$',
0x22EF => '$\\cdots$',
0x22F1 => '$\\ddots$',
0x2308 => '$\\lceil$',
0x2309 => '$\\rceil$',
0x230A => '$\\lfloor$',
0x230B => '$\\rfloor$',
0x2460 => '\\ding{"AC}',
0x2461 => '\\ding{"AD}',
0x2462 => '\\ding{"AE}',
0x2463 => '\\ding{"AF}',
0x2464 => '\\ding{"B0}',
0x2465 => '\\ding{"B1}',
0x2466 => '\\ding{"B2}',
0x2467 => '\\ding{"B3}',
0x2468 => '\\ding{"B4}',
0x2469 => '\\ding{"B5}',
0x25A0 => '\\ding{"6E}',
0x25A1 => '$\\square$',
0x25B2 => '\\ding{"73}',
0x25BC => '\\ding{"74}',
0x25C6 => '\\ding{"75}',
0x25CF => '\\ding{"6C}',
0x25D7 => '\\ding{"77}',
0x2605 => '\\ding{"48}',
0x260E => '\\ding{"25}',
0x261B => '\\ding{"2A}',
0x261E => '\\ding{"2B}',
0x2660 => '$\\spadesuit$',
0x2661 => '$\\heartsuit$',
0x2662 => '$\\diamondsuit$',
0x2663 => '$\\clubsuit$',
0x2665 => '\\ding{"AA}',
0x2666 => '\\ding{"A9}',
0x2701 => '\\ding{"21}',
0x2702 => '\\ding{"22}',
0x2703 => '\\ding{"23}',
0x2704 => '\\ding{"24}',
0x2706 => '\\ding{"26}',
0x2707 => '\\ding{"27}',
0x2708 => '\\ding{"28}',
0x2709 => '\\ding{"29}',
0x270C => '\\ding{"2C}',
0x270D => '\\ding{"2D}',
0x270E => '\\ding{"2E}',
0x270F => '\\ding{"2F}',
0x2710 => '\\ding{"30}',
0x2711 => '\\ding{"31}',
0x2712 => '\\ding{"32}',
0x2713 => '\\ding{"33}',
0x2714 => '\\ding{"34}',
0x2715 => '\\ding{"35}',
0x2716 => '\\ding{"36}',
0x2717 => '\\ding{"37}',
0x2718 => '\\ding{"38}',
0x2719 => '\\ding{"39}',
0x271A => '\\ding{"3A}',
0x271B => '\\ding{"3B}',
0x271C => '\\ding{"3C}',
0x271D => '\\ding{"3D}',
0x271E => '\\ding{"3E}',
0x271F => '\\ding{"3F}',
0x2720 => '\\ding{"40}',
0x2721 => '\\ding{"41}',
0x2722 => '\\ding{"42}',
0x2723 => '\\ding{"43}',
0x2724 => '\\ding{"44}',
0x2725 => '\\ding{"45}',
0x2726 => '\\ding{"46}',
0x2727 => '\\ding{"47}',
0x2729 => '\\ding{"49}',
0x272A => '\\ding{"4A}',
0x272B => '\\ding{"4B}',
0x272C => '\\ding{"4C}',
0x272D => '\\ding{"4D}',
0x272E => '\\ding{"4E}',
0x272F => '\\ding{"4F}',
0x2730 => '\\ding{"50}',
0x2731 => '\\ding{"51}',
0x2732 => '\\ding{"52}',
0x2733 => '\\ding{"53}',
0x2734 => '\\ding{"54}',
0x2735 => '\\ding{"55}',
0x2736 => '\\ding{"56}',
0x2737 => '\\ding{"57}',
0x2738 => '\\ding{"58}',
0x2739 => '\\ding{"59}',
0x273A => '\\ding{"5A}',
0x273B => '\\ding{"5B}',
0x273C => '\\ding{"5C}',
0x273D => '\\ding{"5D}',
0x273E => '\\ding{"5E}',
0x273F => '\\ding{"5F}',
0x2740 => '\\ding{"60}',
0x2741 => '\\ding{"61}',
0x2742 => '\\ding{"62}',
0x2743 => '\\ding{"63}',
0x2744 => '\\ding{"64}',
0x2745 => '\\ding{"65}',
0x2746 => '\\ding{"66}',
0x2747 => '\\ding{"67}',
0x2748 => '\\ding{"68}',
0x2749 => '\\ding{"69}',
0x274A => '\\ding{"6A}',
0x274B => '\\ding{"6B}',
0x274D => '\\ding{"6D}',
0x274F => '\\ding{"6F}',
0x2750 => '\\ding{"70}',
0x2751 => '\\ding{"71}',
0x2752 => '\\ding{"72}',
0x2756 => '\\ding{"76}',
0x2758 => '\\ding{"78}',
0x2759 => '\\ding{"79}',
0x275A => '\\ding{"7A}',
0x275B => '\\ding{"7B}',
0x275C => '\\ding{"7C}',
0x275D => '\\ding{"7D}',
0x275E => '\\ding{"7E}',
0x2761 => '\\ding{"A1}',
0x2762 => '\\ding{"A2}',
0x2763 => '\\ding{"A3}',
0x2764 => '\\ding{"A4}',
0x2765 => '\\ding{"A5}',
0x2766 => '\\ding{"A6}',
0x2767 => '\\ding{"A7}',
0x2776 => '\\ding{"B6}',
0x2777 => '\\ding{"B7}',
0x2778 => '\\ding{"B8}',
0x2779 => '\\ding{"B9}',
0x277A => '\\ding{"BA}',
0x277B => '\\ding{"BB}',
0x277C => '\\ding{"BC}',
0x277D => '\\ding{"BD}',
0x277E => '\\ding{"BE}',
0x277F => '\\ding{"BF}',
0x2780 => '\\ding{"C0}',
0x2781 => '\\ding{"C1}',
0x2782 => '\\ding{"C2}',
0x2783 => '\\ding{"C3}',
0x2784 => '\\ding{"C4}',
0x2785 => '\\ding{"C5}',
0x2786 => '\\ding{"C6}',
0x2787 => '\\ding{"C7}',
0x2788 => '\\ding{"C8}',
0x2789 => '\\ding{"C9}',
0x278A => '\\ding{"CA}',
0x278B => '\\ding{"CB}',
0x278C => '\\ding{"CC}',
0x278D => '\\ding{"CD}',
0x278E => '\\ding{"CE}',
0x278F => '\\ding{"CF}',
0x2790 => '\\ding{"D0}',
0x2791 => '\\ding{"D1}',
0x2792 => '\\ding{"D2}',
0x2793 => '\\ding{"D3}',
0x2794 => '\\ding{"D4}',
0x2798 => '\\ding{"D8}',
0x2799 => '\\ding{"D9}',
0x279A => '\\ding{"DA}',
0x279B => '\\ding{"DB}',
0x279C => '\\ding{"DC}',
0x279D => '\\ding{"DD}',
0x279E => '\\ding{"DE}',
0x279F => '\\ding{"DF}',
0x27A0 => '\\ding{"E0}',
0x27A1 => '\\ding{"E1}',
0x27A2 => '\\ding{"E2}',
0x27A3 => '\\ding{"E3}',
0x27A4 => '\\ding{"E4}',
0x27A5 => '\\ding{"E5}',
0x27A6 => '\\ding{"E6}',
0x27A7 => '\\ding{"E7}',
0x27A8 => '\\ding{"E8}',
0x27A9 => '\\ding{"E9}',
0x27AA => '\\ding{"EA}',
0x27AB => '\\ding{"EB}',
0x27AC => '\\ding{"EC}',
0x27AD => '\\ding{"ED}',
0x27AE => '\\ding{"EE}',
0x27AF => '\\ding{"EF}',
0x27B1 => '\\ding{"F1}',
0x27B2 => '\\ding{"F2}',
0x27B3 => '\\ding{"F3}',
0x27B4 => '\\ding{"F4}',
0x27B5 => '\\ding{"F5}',
0x27B6 => '\\ding{"F6}',
0x27B7 => '\\ding{"F7}',
0x27B8 => '\\ding{"F8}',
0x27B9 => '\\ding{"F9}',
0x27BA => '\\ding{"FA}',
0x27BB => '\\ding{"FB}',
0x27BC => '\\ding{"FC}',
0x27BD => '\\ding{"FD}',
0x27BE => '\\ding{"FE}' 
};

1;
