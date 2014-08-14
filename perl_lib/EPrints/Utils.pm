######################################################################
#
# EPrints::Utils
#
######################################################################
#
#
######################################################################

=pod

=for Pod2Wiki

=head1 NAME

B<EPrints::Utils> - Utility functions for EPrints.

=head1 SYNOPSIS
	
	$boolean = EPrints::Utils::is_set( $object ) 
	# return true if an object/scalar/array has any data in it

	# copy the contents of the url to a file
	$response = EPrints::Utils::wget( 
		$handle, 
		"http://www.eprints.org/index.php", 
		"temp_dir/my_file" ) 
	if($response->is_sucess()){ do something...}
	
	$name = { given=>"Wendy", family=>"Hall", honourific=>"Dame" };
	# return Dame Wendy Hall
	$string = EPrints::Utils::make_name_string( $name, 1 );
	# return Dame Hall, Wendy
	$string = EPrints::Utils::make_name_string( $name, 0 );
	
	# returns http://www.eprints.org?var=%3Cfoo%3E
	$string = EPrints::Utils::url_escape( "http://www.eprints.org?var=<foo>" ); 
	
	$esc_string = EPrints::Utils::escape_filename( $string );
	$string = EPrints::Utils::unescape_filename( $esc_string );
	
	$filesize_text = EPrints::Utils::human_filesize( 3300 ); 
	# returns "3kB"

=head1 DESCRIPTION

This package contains functions which don't belong anywhere else.

=head1 METHODS

=over 4

=cut

package EPrints::Utils;

use File::Copy qw();
use Text::Wrap qw();
use LWP::UserAgent;
use URI;
use EPrints::Const qw( :crypt );

my $USE_CRYPT_BLOWFISH = 1;
eval "use Authen::Passphrase::BlowfishCrypt; 1" or $USE_CRYPT_BLOWFISH = 0;

use strict;

$EPrints::Utils::FULLTEXT = "documents";

BEGIN {
	eval "use Term::ReadKey";
	eval "use Compat::Term::ReadKey" if $@;
}


######################################################################

=begin InternalDoc

=item $cmd = EPrints::Utils::prepare_cmd($cmd,%VARS)

Prepare command string $cmd by substituting variables (specified by
C<$(varname)>) with their value from %VARS (key is C<varname>). All %VARS are
quoted before replacement to make it shell-safe.

If a variable is specified in $cmd, but not present in %VARS a die is thrown.

=end

=cut

######################################################################
#TODO ask brody what the hell this is :-P pm5
#DEPRECATED in favour of EPrints::Repository::invocation?

sub prepare_cmd {
	my ($cmd, %VARS) = @_;
	$cmd =~ s/\$\(([\w_]+)\)/defined($VARS{$1}) ? quotemeta($VARS{$1}) : die("Unspecified variable $1 in $cmd")/seg;
	$cmd;
}

######################################################################

=pod

=item $string = EPrints::Utils::make_name_string( $name, [$familylast] )

Return a string containing the name described in the hash reference
$name. 

The keys of the hash are one or more of given, family, honourific and
lineage. The values are utf-8 strings.

Normally the result will be:

"family lineage, honourific given"

but if $familylast is true then it will be:

"honourific given family lineage"

=cut

######################################################################

sub make_name_string
{
	my( $name, $familylast ) = @_;

	#EPrints::abort "make_name_string expected hash reference" unless ref($name) eq "HASH";
	return "make_name_string expected hash reference" unless ref($name) eq "HASH";

	my $firstbit = "";
	if( defined $name->{honourific} && $name->{honourific} ne "" )
	{
		$firstbit = $name->{honourific}." ";
	}
	if( defined $name->{given} )
	{
		$firstbit.= $name->{given};
	}
	
	
	my $secondbit = "";
	if( defined $name->{family} )
	{
		$secondbit = $name->{family};
	}
	if( defined $name->{lineage} && $name->{lineage} ne "" )
	{
		$secondbit .= " ".$name->{lineage};
	}

	
	if( defined $familylast && $familylast )
	{
		return $firstbit." ".$secondbit;
	}
	
	return $secondbit.", ".$firstbit;
}



######################################################################

=pod

=item $str = EPrints::Utils::wrap_text( $text, [$width], [$init_tab], [$sub_tab] )

Wrap $text to be at most $width (or 80 if undefined) characters per line. As a
special case $width may be C<console>, in which case the width used is the
current console width (L<Term::ReadKey>).

$init_tab and $sub_tab allow indenting on the first and subsequent lines
respectively (see L<Text::Wrap> for more information).

=cut

######################################################################

sub wrap_text
{
	my( $text, $width, $init_tab, $sub_tab ) = @_;

	$width ||= 80;
	if( $width eq 'console' )
	{
		($width) = Term::ReadKey::GetTerminalSize;
		$width ||= 80;
	}
	$width = 80 if $width < 1;
	$init_tab = "" if( !defined $init_tab );
	$sub_tab = "" if( !defined $sub_tab );

	local $Text::Wrap::columns = $width;
	local $Text::Wrap::huge = "overflow";

	return join "", Text::Wrap::fill( $init_tab, $sub_tab, $text );
}



######################################################################

=pod

=item $boolean = EPrints::Utils::is_set( $r )

Recursive function. 

Return false if $r is not set.

If $r is a scalar then returns true if it is not an empty string.

For arrays and hashes return true if at least one value of them
is_set().

This is used to see if a complex data structure actually has any data
in it.

=cut

######################################################################

sub is_set
{
	my( $r ) = @_;

	return 0 if( !defined $r );
		
	if( ref($r) eq "" )
	{
		return ($r ne "");
	}
	if( ref($r) eq "ARRAY" )
	{
		foreach( @$r )
		{
			return( 1 ) if( is_set( $_ ) );
		}
		return( 0 );
	}
	if( ref($r) eq "HASH" )
	{
		foreach( keys %$r )
		{
			return( 1 ) if( is_set( $r->{$_} ) );
		}
		return( 0 );
	}
	# Hmm not a scalar, or a hash or array ref.
	# Lets assume it's set. (it is probably a blessed thing)
	return( 1 );
}

# widths smaller than about 3 may totally break, but that's
# a stupid thing to do, anyway.

######################################################################

=pod

=item $string = EPrints::Utils::tree_to_utf8( $tree, $width, [$pre], [$whitespace_before], [$ignore_a] )

Convert a XML DOM tree to a utf-8 encoded string.

If $width is set then word-wrap at that many characters.

XHTML elements are removed with the following exceptions:

<br /> is converted to a newline.

<p>...</p> will have a blank line above and below.

<img /> will be replaced with the content of the alt attribute.

<hr /> will, if a width was specified, insert a line of dashes.

<a href="foo">bar</a> will be converted into "bar <foo>" unless ignore_a is set.

=cut

######################################################################

sub tree_to_utf8
{
	my( $node, $width, $pre, $whitespace_before, $ignore_a ) = @_;

	$whitespace_before = 0 unless defined $whitespace_before;

	unless( EPrints::XML::is_dom( $node ) )
	{
		print STDERR "Oops. tree_to_utf8 got as a node: $node\n";
	}
	if( EPrints::XML::is_dom( $node, "NodeList" ) )
	{
# Hmm, a node list, not a node.
		my $string = "";
		my $ws = $whitespace_before;
		for( my $i=0 ; $i<$node->length ; ++$i )
		{
			$string .= tree_to_utf8( 
					$node->item( $i ), 
					$width,
					$pre,
					$ws,
					$ignore_a );
			$ws = _blank_lines( $ws, $string );
		}
		return $string;
	}

	if( EPrints::XML::is_dom( $node, "Text" ) ||
		EPrints::XML::is_dom( $node, "CDataSection" ) )
	{
		my $v = $node->nodeValue();
		utf8::decode($v) unless utf8::is_utf8($v);
		$v =~ s/[\s\r\n\t]+/ /g unless( $pre );
		return $v;
	}
	my $name = $node->nodeName();

	my $string = "";
	my $ws = $whitespace_before;
	foreach( $node->getChildNodes )
	{
		$string .= tree_to_utf8( 
				$_,
				$width, 
				( $pre || $name eq "pre" || $name eq "mail" ),
				$ws,
				$ignore_a );
		$ws = _blank_lines( $ws, $string );
	}

	if( $name eq "fallback" )
	{
		$string = "*".$string."*";
	}

	# <hr /> only makes sense if we are generating a known width.
	if( defined $width && $name eq "hr" )
	{
		$string = "\n"."-"x$width."\n";
	}

	# Handle wrapping block elements if a width was set.
	if( defined $width && ( $name eq "p" || $name eq "mail" ) )
	{
		$string = wrap_text( $string, $width );
	}
	$ws = $whitespace_before;
	if( $name eq "p" )
	{
		while( $ws < 2 ) { $string="\n".$string; ++$ws; }
	}
	$ws = _blank_lines( $whitespace_before, $string );
	if( $name eq "p" )
	{
		while( $ws < 1 ) { $string.="\n"; ++$ws; }
	}
	if( $name eq "br" )
	{
		while( $ws < 1 ) { $string.="\n"; ++$ws; }
	}
	if( $name eq "img" )
	{
		my $alt = $node->getAttribute( "alt" );
		$string = $alt if( defined $alt );
	}
	if( $name eq "a" && !$ignore_a)
	{
		my $href = $node->getAttribute( "href" );
		$string .= " <$href>" if( defined $href );
	}
	return $string;
}

sub _blank_lines
{
	my( $n, $str ) = @_;

	$str = "\n"x$n . $str;
	$str =~ s/\[[^\]]*\]//sg;
	$str =~ s/[ 	\r]+//sg;
	my $ws;
	for( $ws = 0; substr( $str, (length $str) - 1 - $ws, 1 ) eq "\n"; ++$ws ) {;}

	return $ws;
}

######################################################################

=begin InternalDoc

=item $ok = EPrints::Utils::copy( $source, $target )

Copy $source file to $target file without alteration.

Return true on success (sets $! on error).

=end

=cut

######################################################################

sub copy
{
	my( $source, $target ) = @_;
	
	return File::Copy::copy( $source, $target );
}

######################################################################

=pod

=item $response = EPrints::Utils::wget( $session, $source, $target )

Copy $source file or URL to $target file without alteration.

Will fail if $source is a "file:" and "enable_file_imports" is false or if $source is any other scheme and "enable_web_imports" is false.

Returns the HTTP response object: use $response->is_success to check whether the copy succeeded.

=cut

######################################################################

sub wget
{
	my( $session, $url, $target ) = @_;

	$target = "$target";

	$url = URI->new( $url );

	if( !defined($url->scheme) )
	{
		$url->scheme( "file" );
	}

	if( $url->scheme eq "file" )
	{
		if( !$session->config( "enable_file_imports" ) )
		{
			return HTTP::Response->new( 403, "Access denied by configuration: file imports disabled" );
		}
	}
	elsif( !$session->config( "enable_web_imports" ) )
	{
		return HTTP::Response->new( 403, "Access denied by configuration: web imports disabled" );
	}

	my $ua = LWP::UserAgent->new();

	my $r = $ua->get( $url,
		":content_file" => $target
	);

	return $r;
}

######################################################################

=begin InternalDoc

=item $ok = EPrints::Utils::rmtree( $full_path )

Unlinks the path and everything in it.

Return true on success.

=end

=cut

######################################################################

sub rmtree
{
	my( $full_path ) = @_;

	$full_path = "$full_path";

	return 1 if( !-e $full_path );

	my $dh;
	if( !opendir( $dh, $full_path ) )
	{
		print STDERR "Failed to open dir $full_path: $!\n";
		return 0;
	}
	my @dir = ();
	while( my $fn = readdir( $dh ) )
	{
		next if $fn eq ".";
		next if $fn eq "..";
		my $file = "$full_path/$fn";
		if( -d $file )
		{
			push @dir, $file;	
			next;
		}
		
		if( !unlink( $file ) )
		{
			print STDERR "Failed to unlink $file: $!\n";
			return 0;
		}
	}
	closedir( $dh );

	foreach my $a_dir ( @dir )			
	{
		EPrints::Utils::rmtree( $a_dir );
	}
	
	if( !rmdir( $full_path ) )
	{
		print STDERR "Failed to rmdir $full_path: $!\n";
		return 0;
	}

	return 1;
}


######################################################################
#=pod
#
# =item $xhtml = EPrints::Utils::render_citation( $cstyle, %params );
#
# Render the given object (EPrint, User, etc) using the citation style
# $cstyle. If $url is specified then the <ep:linkhere> element will be
# replaced with a link to that URL.
#
# in=>.. describes where this came from in case it needs to report an
# error.
#
# session=> is required
#
# item => is required (the epobject being cited).
#
# url => is option if the item is to be linked.
#
#=cut
######################################################################

sub render_citation
{
	my( $cstyle, %params ) = @_;

	# This should belong to the base class of EPrint User Subject and
	# SavedSearch, if we were better OO people...

	my $collapsed = EPrints::XML::EPC::process( $cstyle, %params, in=>"render_citation" );
	my $r = _render_citation_aux( $collapsed, %params );

	return $r;
}

sub _render_citation_aux
{
	my( $node, %params ) = @_;

	my $addkids = $node->hasChildNodes;

	my $rendered;
	if( EPrints::XML::is_dom( $node, "Element" ) )
	{
		my $name = $node->tagName;
		$name =~ s/^ep://;
		$name =~ s/^cite://;

		if( $name eq "iflink" )
		{
			$rendered = $params{session}->make_doc_fragment;
			$addkids = defined $params{url};
		}
		elsif( $name eq "ifnotlink" )
		{
			$rendered = $params{session}->make_doc_fragment;
			$addkids = !defined $params{url};
		}
		elsif( $name eq "linkhere" )
		{
			if( defined $params{url} )
			{
				$rendered = $params{session}->make_element( 
					"a",
					class=>$params{class},
					onclick=>$params{onclick},
					target=>$params{target},
					href=> $params{url} );
			}
			else
			{
				$rendered = $params{session}->make_doc_fragment;
			}
		}
	}

	if( !defined $rendered )
	{
		$rendered = $params{session}->clone_for_me( $node );
	}

	if( $addkids )
	{
		foreach my $child ( $node->getChildNodes )
		{
			$rendered->appendChild(
				_render_citation_aux( 
					$child,
					%params ) );			
		}
	}
	return $rendered;
}



######################################################################

=begin InternalDoc

=item $metafield = EPrints::Utils::field_from_config_string( $dataset, $fieldname )

Return the EPrint::MetaField from $dataset with the given name.

If fieldname has a semicolon followed by render options then these
are passed as render options to the new EPrints::MetaField object.

=end

=cut

######################################################################

sub field_from_config_string
{
	my( $dataset, $fieldname ) = @_;

	my %q = ();
	if( $fieldname =~ s/^([^;]*)(;(.*))?$/$1/ )
	{
		if( defined $3 )
		{
			foreach my $render_pair ( split( /;/, $3 ) )
			{
				my( $k, $v ) = split( /=/, $render_pair );
				$v = 1 unless defined $v;
				if( $k eq "options" )
				{
					$q{$k} = [ split( ",", $v ) ];
					next;
				}
				$q{($k eq "top"?"top":"render_$k")} = $v;
			}
		}
	}

	my $field;
	my @join = ();
	
	my @fnames = split /\./, $fieldname;
	foreach my $fname ( @fnames )
	{
		if( !defined $dataset )
		{
			EPrints::abort( "Attempt to get a field or subfield from a non existent dataset. Could be due to a sub field of a inappropriate field type." );
		}
		$field = $dataset->get_field( $fname );
		if( !defined $field )
		{
			EPrints::abort( "Dataset ".$dataset->confid." does not have a field '$fname'" );
		}
		push @join, [ $field, $dataset ];
		if( $field->is_type( "subobject", "itemref" ) )
		{
			my $datasetid = $field->get_property( "datasetid" );
			$dataset = $dataset->get_repository->get_dataset( $datasetid );
		}
		else
		{
			# for now, force an error if an attempt is made
			# to get a sub-field from a field other than
			# subobject or itemid.
			$dataset = undef;
		}
	}

	if( !defined $field )
	{
		EPrints::abort( "Can't make field from config_string: $fieldname" );
	}
	pop @join;
	if( scalar @join )
	{
		$q{"join_path"} = \@join;
	}

	if( scalar keys %q  )
	{
		$field = $field->clone;
	
		foreach my $k ( keys %q )
		{
			$field->set_property( $k, $q{$k} );
		}
	}
	
	return $field;
}

######################################################################

=begin InternalDoc

=item $string = EPrints::Utils::get_input( $regexp, [$prompt], [$default] )

Read input from the keyboard.

Prints the promp and default value, if any. eg.
 How many fish [5] >

Return the value the user enters at the keyboard.

If the value does not match the regexp then print the prompt again
and try again.

If a default is set and the user just hits return then the default
value is returned.

=end

=cut

######################################################################

sub get_input
{
	my( $regexp, $prompt, $default ) = @_;

	$prompt = "" if( !defined $prompt);
	$prompt .= " [$default] " if( defined $default );
	$prompt .= "? ";
	for(;;)
	{
		print wrap_text( $prompt, 'console' );

		my $in = Term::ReadKey::ReadLine(0);
		$in =~ s/\015?\012?$//s;
		if( $in eq "" && defined $default )
		{
			return $default;
		}
		if( $in=~m/^$regexp$/ )
		{
			return $in;
		}
		else
		{
			print "Bad Input, try again.\n";
		}
	}
}

######################################################################

=for InteralDoc

=item EPrints::Utils::get_input_hidden( $regexp, [$prompt], [$default] )

Get input from the console without echoing the entered characters 
(mostly useful for getting passwords). Uses L<Term::ReadKey>.

Identical to get_input except the characters don't appear.

=cut

######################################################################

sub get_input_hidden
{
	my( $regexp, $prompt, $default ) = @_;

	$prompt = "" if( !defined $prompt);
	$prompt .= " [$default] " if( defined $default );
	$prompt .= "? ";
	for(;;)
	{
		print wrap_text( $prompt, 'console' );
		
		Term::ReadKey::ReadMode('noecho');
		my $in = Term::ReadKey::ReadLine( 0 );
		Term::ReadKey::ReadMode('normal');
		$in =~ s/\015?\012?$//s;
		print "\n";

		if( $in eq "" && defined $default )
		{
			return $default;
		}
		if( $in=~m/^$regexp$/ )
		{
			return $in;
		}
		else
		{
			print "Bad Input, try again.\n";
		}
	}

}

######################################################################

=begin InternalDoc

=item EPrints::Utils::get_input_confirm( [$prompt], [$quick], [$default] )

Asks the user for confirmation (yes/no). If $quick is true only checks for a
single-character input ('y' or 'n').

If $default is '1' defaults to yes, if '0' defaults to no.

Returns true if the user answers 'yes' or false for any other value.

=end

=cut

######################################################################

sub get_input_confirm
{
	my( $prompt, $quick, $default ) = @_;

	$prompt = "" if( !defined $prompt );
	if( defined($default) )
	{
		$default = $default ? "yes" : "no";
	}

	if( $quick )
	{
		$default = substr($default,0,1) if defined $default;
		$prompt .= " [y/n] ? ";
		print wrap_text( $prompt, 'console' );

		my $in="";
		while( $in ne "y" && $in ne "n" )
		{
			Term::ReadKey::ReadMode( 'raw' );
			$in = lc(Term::ReadKey::ReadKey( 0 ));
			Term::ReadKey::ReadMode( 'normal' );
			$in = $default if ord($in) == 10 && defined $default;
		}
		if( $in eq "y" ) { print wrap_text( "es" ); }
		if( $in eq "n" ) { print wrap_text( "o" ); }
		print "\n";
		return( $in eq "y" );
	}
	else
	{
		$prompt .= defined($default) ? " [$default] ? " : " [yes/no] ? ";
		my $in="";
		while($in ne "no" && $in ne "yes")
		{
			print wrap_text( $prompt, 'console' );

			$in = lc(Term::ReadKey::ReadLine( 0 ));
			$in =~ s/\015?\012?$//s;
			$in = $default if length($in) == 0 && defined $default;
		}
		return( $in eq "yes" );
	}
	
	return 0;
}

######################################################################

=begin InternalDoc

=item $clone_of_data = EPrints::Utils::clone( $data )

Deep copies the data structure $data, following arrays and hashes.

Does not handle blessed items.

Useful when we want to modify a temporary copy of a data structure 
that came from the configuration files.

=end

=cut

######################################################################

sub clone
{
	my( $data ) = @_;

	if( ref($data) eq "" )
	{
		return $data;
	}
	if( ref($data) eq "ARRAY" )
	{
		my $r = [];
		foreach( @{$data} )
		{
			push @{$r}, clone( $_ );
		}
		return $r;
	}
	if( ref($data) eq "HASH" )
	{
		my $r = {};
		foreach( keys %{$data} )
		{
			$r->{$_} = clone( $data->{$_} );
		}
		return $r;
	}


	# dunno
	return $data;			
}

# crypt_password( $value, $session )
sub crypt_password { &crypt( $_[0] ) }

=item $crypt = EPrints::Utils::crypt( $value [, $method ] )

Generate a one-way crypt of $value e.g. for storing passwords.

For available methods see L<EPrints::Const>. Defaults to EP_CRYPT_SHA512.

=cut

sub crypt
{
	my( $value, $method ) = @_;

	return undef if !EPrints::Utils::is_set( $value );

	# backwards compatibility
	if( UNIVERSAL::isa( $method, "EPrints::Repository" ) ) {
		$method = EP_CRYPT_CRYPT;
	}
	elsif( !defined $method ) {
		$method = EP_CRYPT_SHA512;
	}

	srand;
	my @saltset = ('a'..'z', 'A'..'Z', '0'..'9', '.', '/');
	my $salt = join '', @saltset[
			int(rand(scalar(@saltset))),
			int(rand(scalar(@saltset)))
		];

	if( $method eq EP_CRYPT_SHA512 )
	{
		# calculate the sha512 of the salt + value (avoids two identical
		# passwords resulting in the same hash)
		my $crypt = Digest::SHA::sha512( $salt . $value );

		# repeatedly calculate the hash, which makes it computationally
		# expensive to brute-force the resulting hash
		my $rounds = 10000;
		while(--$rounds) {
			$crypt = Digest::SHA::sha512( $crypt );
		}
		# once more + hex to get $rounds in total
		$crypt = Digest::SHA::sha512_hex( $crypt );

		# store the crypt as a URI for easy serialisation
		my $uri = URI->new;
		$uri->query_form(
			method => EP_CRYPT_SHA512,
			salt => $salt,
			digest => $crypt,
		);

		return "$uri";
	}
	elsif( $method eq EP_CRYPT_BLOWFISH && $USE_CRYPT_BLOWFISH )
	{
		# Blowfish cost factor (2^n rounds)
		my $cost = 12;
		# Blowfish requires a 16-byte salt. We can just ignore the two bytes
		# calculated above, and let the library generate its own salt.
		my $ppr = Authen::Passphrase::BlowfishCrypt->new(
			cost => $cost,
			salt_random => 1,
			passphrase => $value
		);

		return $ppr->as_crypt();
	}
	elsif( $method eq EP_CRYPT_CRYPT )
	{
		return CORE::crypt($value ,$salt);
	}

	EPrints->abort( "Unsupported or unknown crypt method: $method" );
}

=item $bool = EPrints::Utils::crypt_equals( $crypt, $value )

Test whether the $crypt as previously returned by L</crypt> for $value matches $value.

=cut

sub crypt_equals
{
	my( $crypt, $value ) = @_;

	return undef if !EPrints::Utils::is_set( $value );

	# EP_CRYPT_BLOWFISH
	if( $USE_CRYPT_BLOWFISH && $crypt =~ /^\$2a?\$..\$.{22}.{31}$/ ) {
		my $ppr = Authen::Passphrase::BlowfishCrypt->from_crypt( $crypt );
		return $ppr->match( $token );
	}

	# EP_CRYPT_CRYPT
	if( $crypt !~ /^\?/ ) {
		return $crypt eq CORE::crypt($value, substr($crypt, 0, 2));
	}

	# unpack the crypt URI
	my %q = URI->new( $crypt )->query_form;
	( my $method, my $salt, $crypt ) = @q{ qw( method salt digest ) };

	if( $method eq EP_CRYPT_SHA512 )
	{
		my $digest = Digest::SHA::sha512( $salt . $value );

		my $rounds = 10000;
		while(--$rounds) {
			$digest = Digest::SHA::sha512( $digest );
		}
		$digest = Digest::SHA::sha512_hex( $digest );

		return $crypt eq $digest;
	}

	EPrints->abort( "Unsupported or unknown crypt method: $method" );
}

# Escape everything AFTER the last /

######################################################################

=pod

=item $string = EPrints::Utils::url_escape( $url )

Escape the given $url, so that it can appear safely in HTML.

=cut

######################################################################

sub url_escape
{
	my( $url ) = @_;
	
	$url =~ s/([%'<>^ "])/sprintf( '%%%02X', ord($1) )/eg;

	return $url;
}

=item $url = EPrints::Utils::uri_escape_utf8( $str [, $ptn ] )

Escape utf8 encoded string $str for use in a URI.

Valid characters are [A-Za-z0-9\-\._~"].

=cut

# Copied from URI::Escape::uri_escape_utf8, which may not be available on
# systems with very old versions of URI that get into Apache before our copy
# does.
sub uri_escape_utf8
{
	my $text = shift;

	utf8::encode( $text );

	return URI::Escape::uri_escape($text, @_);
}

######################################################################

=begin InternalDoc

=item $long = EPrints::Utils::ip2long( $ip )

Convert quad-dotted notation to long

=item $ip = EPrints::Utils::long2ip( $ip )

Convert long to quad-dotted notation

=end

=cut

######################################################################

sub ip2long
{
	my( $ip ) = @_;
	my $long = 0;
	foreach my $octet (split(/\./, $ip)) {
		$long <<= 8;
		$long |= $octet;
	}
	return $long;
}

sub long2ip
{
	my( $long ) = @_;
	my @octets;
	for(my $i = 3; $i >= 0; $i--) {
		$octets[$i] = ($long & 0xFF);
		$long >>= 8;
	}
	return join('.', @octets);
}

######################################################################

=begin InternalDoc

=item EPrints::Utils::cmd_version( $progname )

Print out a "--version" style message to STDOUT.

$progname is the name of the current script.

=end

=cut

######################################################################

sub cmd_version
{
	my( $progname ) = @_;

	$progname = $0;
	$progname =~ s/^.*\///;

	print $progname." ".EPrints->human_version." [Schema $EPrints::Database::DBVersion]\n\n";

	my $license_bin = $EPrints::SystemSettings::conf->{base_path} . "/bin/epadmin";
	open(my $fh, "<", $license_bin) or die "Error opening $license_bin: $!";
	COPYRIGHT: while(<$fh>)
	{
		next if $_ !~ /^=for COPYRIGHT BEGIN/;
		<$fh>;
		while(<$fh>)
		{
			last COPYRIGHT if $_ =~ /^=for COPYRIGHT END/;
			print $_;
		}
	}
	LICENSE: while(<$fh>)
	{
		next if $_ !~ /^=for LICENSE BEGIN/;
		<$fh>;
		while(<$fh>)
		{
			last LICENSE if $_ =~ /^=for LICENSE END/;
			print $_;
		}
	}
	close($fh);
	exit;
}

######################################################################

=pod

=item $esc_string = EPrints::Utils::escape_filename( $string )

Take a value and escape it to be a legal filename to go in the /view/
section of the site.

=cut

######################################################################

sub escape_filename
{
	my( $fileid ) = @_;

	return "NULL" if( $fileid eq "" );

	$fileid = "$fileid";
	utf8::decode($fileid);
	# now we're working with a utf-8 tagged string, temporarily.

	# Valid chars: 0-9, a-z, A-Z, ",", "-", " "

	# Escape to either '=XX' (8bit) or '==XXXX' (16bit)
	$fileid =~ s/([^0-9a-zA-Z,\- ])/
		ord($1) < 256 ?
			sprintf("=%02X",ord($1)) :
			sprintf("==%04X",ord($1))
	/exg;

	# Replace spaces with "_"
	$fileid =~ s/ /_/g;

	utf8::encode($fileid);

	return $fileid;
}

######################################################################

=pod

=item $string = EPrints::Utils::unescape_filename( $esc_string )

Unescape a string previously escaped with escape_filename().

=cut

######################################################################

sub unescape_filename
{
	my( $fileid ) = @_;

	if( !utf8::is_utf8( $fileid ) )
	{
		# should be ASCII, but we're turning into something
		# with unicode chars in.
		utf8::upgrade( $fileid ) ;
	}

	$fileid =~ s/_/ /g;
	$fileid =~ s/==(....)/chr(hex($1))/eg;
	$fileid =~ s/=(..)/chr(hex($1))/eg;

	return $fileid;
}

######################################################################

=pod

=item $filesize_text = EPrints::Utils::human_filesize( $size_in_bytes )

Return a human readable version of a filesize. If 0-999B then show as
bytes, if 1-999kB show as kB otherwise show as MB, GB, TB, PB, or EB
following the same pattern.

eg. Input of 1234 gives "1kB", input of 934 gives "934B".

This is not internationalised, I don't think it needs to be. Let me
know if this is a problem. support@eprints.org

=cut

######################################################################

sub human_filesize
{
	my( $size_in_bytes ) = @_;

	my $tsize = $size_in_bytes;
	my $prefixes = [ 'B', 'kB', 'MB', 'GB', 'TB', 'PB', 'EB' ];
	my $i = 0;
	while(1) {
		### Modified by QUT, 20130521: converted to SI
		last if( $tsize < 1000 || $i >= scalar( @$prefixes ) - 1 );
		$tsize =  int( $tsize / 1000 );
		$i++;
	}

	$tsize .= $prefixes->[$i];
	return $tsize;
}

my %REQUIRED_CACHE;
sub require_if_exists
{
	my( $module, @params ) = @_;

	# this is very slightly faster than just calling eval-require, because
	# perl doesn't have to build the eval environment
	if( !exists $REQUIRED_CACHE{$module} )
	{
		local $SIG{__DIE__};
		$REQUIRED_CACHE{$module} = @params ?
		# require_if_exists( "Foo::Bar", "1.2" )
			eval "use $module @params; 1" :
		# require_if_exists( "Foo::Bar" )
			eval "require $module";
	}

	return $REQUIRED_CACHE{$module};
}

sub chown_for_eprints
{
	my( $file ) = @_;

	my $uid = $EPrints::SystemSettings::conf->{group_uid};
	my $gid = $EPrints::SystemSettings::conf->{group_gid};

	if( !defined $uid || !defined $gid )
	{
		my $group = $EPrints::SystemSettings::conf->{group};
		my $username = $EPrints::SystemSettings::conf->{user};

		(undef,undef,$uid,undef) = EPrints::Platform::getpwnam( $username );
		$gid = EPrints::Platform::getgrnam( $group );

		$EPrints::SystemSettings::conf->{group_uid} = $uid;
		$EPrints::SystemSettings::conf->{group_gid} = $gid;
	}

	EPrints::Platform::chown( $uid, $gid, $file );
}


# Return the last modification time of a file.

sub mtime
{
	my( $file ) = @_;

	my @filestat = stat( $file );

	return $filestat[9];
}


# return a quoted string safe to go in javascript

my %JSON_ESC = (
	"\b" => "\\b",
	"\f" => "\\f",
	"\n" => "\\n",
	"\r" => "\\r",
	"\t" => "\\t",
	"\"" => "\\\"",
	"\'" => "\\'",
	"\\" => "\\\\",
	"\/" => "\\\/",
);
sub js_string
{
	my( $string ) = @_;

	return 'null' if !defined $string || $string eq '';

	$string =~ s/([\x2f\x22\x5c\n\r\t\f\b])/$JSON_ESC{$1}/g;
	$string =~ s/([\x00-\x08\x0b\x0e-\x1f])/'\\u00' . unpack('H2', $1)/eg;

	return "\"$string\"";
}

# EPrints::Utils::process_parameters( $params, $defaults );
#  for each key in the hash ref $defaults, if $params->{$key} is not set
#  then it's set to the default from the $defaults hash.
#  Also warns if unknown paramters were passed.

sub process_parameters($$)
{
	my( $params, $defaults ) = @_;

	foreach my $k ( keys %{$defaults} )
	{
		if( !defined $params->{$k} ) 
		{
			if( $defaults->{$k} eq "*REQUIRED*" )
			{
				my @c = caller(1);
				EPrints::abort( "Required parameter '$k' not passed to ".$c[3]." at ".$c[1]." line ".$c[2] );
			}
			$params->{$k} = $defaults->{$k}; 
		}
	}

	foreach my $k ( keys %{$params} )
	{
		if( !defined $defaults->{$k} )
		{
			my @c = caller(1);
			warn "Unexpected parameter '$k' passed to ".$c[3]." at ".$c[1]." line ".$c[2]."\n";
		}
	}
}

######################################################################
# Redirect as this function has been moved.
######################################################################
sub render_xhtml_field { return EPrints::Extras::render_xhtml_field( @_ ); }

sub make_relation
{
	return "http://eprints.org/relation/" . $_[0];
}

# Creates a sitemap URL given the following attributes:
# 	$urldef->{loc} (required)
# 	$urldef->{lastmod} (optional)
# 	$urldef->{changefreq} (optional)
# 	$urldef->{priority} (optional)
#
# See http://www.sitemaps.org/protocol.php
#
sub make_sitemap_url
{
	my( $repo, $urldef ) = @_;

	return $repo->make_doc_fragment unless( EPrints::Utils::is_set( $urldef ) && defined $urldef->{loc} );

	my $url = $repo->make_element( 'url' );
	my $loc = $repo->make_element( 'loc' );	
	$loc->appendChild( $repo->make_text( $urldef->{loc} ) );
	$url->appendChild( $loc );

	foreach my $attribute ( "lastmod", "changefreq", "priority" )
	{
		next unless( EPrints::Utils::is_set( $urldef->{$attribute} ) );

		my $tag = $repo->make_element( $attribute );
		$tag->appendChild( $repo->make_text( $urldef->{$attribute} ) );
		$url->appendChild( $tag );
	}

	return $url;
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

