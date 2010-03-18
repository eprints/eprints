######################################################################
#
# EPrints::XHTML
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2009 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################


=pod

=for Pod2Wiki

=head1 NAME

B<EPrints::XHTML> - XHTML Module

=head1 SYNOPSIS

	$xhtml = $repo->xhtml;

	$utf8_string = $xhtml->to_xhtml( $dom_node, %opts );

	$xhtml_dom_node = $xhtml->input_field( $name, $value, type => "text" );
	$xhtml_dom_node = $xhtml->hidden_field( $name, $value );
	$xhtml_dom_node = $xhtml->text_area_field( $name, $value, rows => 4 );
	$xhtml_dom_node = $xhtml->form( "get", $url );

	$xhtml_dom_node = $xhtml->data_element( $name, $value, indent => 4 );

	$page = $xhtml->page( %opts );

=head1 DESCRIPTION

The XHTML object facilitates the creation of XHTML objects.

=head1 METHODS

=over 4

=cut

package EPrints::XHTML;

use strict;

@EPrints::XHTML::COMPRESS_TAGS = qw/br hr img link input meta/;
%EPrints::XHTML::COMPRESS_TAG = map { $_ => 1 } @EPrints::XHTML::COMPRESS_TAGS;

# $xhtml = new EPrints::XHTML( $repository )
#
# Contructor, should be called by Repository only.

sub new($$)
{
	my( $class, $repository ) = @_;

	my $self = bless { repository => $repository }, $class;

	return $self;
}

=item $node = $xhtml->form( $method [, $action] )

Returns an XHTML form. If $action isn't defined uses the current URL.

=cut

sub form
{
	my( $self, $method, $action ) = @_;
	
	$method = lc($method);
	if( !defined $action )
	{
		$action = $self->{repository}->current_url( query => 0 );
	}

	my $form = $self->{repository}->xml->create_element( "form",
		method => $method,
		'accept-charset' => "utf-8",
		action => $action,
		);
	if( $method eq "post" )
	{
		$form->setAttribute( enctype => "multipart/form-data" );
	}

	return $form;
}

=item $node = $xhtml->input_field( $name, $value, %opts )

	$node = $xhtml->input_field( "name", "Bob", type => "text" );

Returns an XHTML input field with name $name and value $value. Specify "noenter" to prevent the form being submitted when the user presses the enter key.

=cut

sub input_field
{
	my( $self, $name, $value, @opts ) = @_;

	my $noenter;
	for(my $i = 0; $i < @opts; $i+=2)
	{
		if( $opts[$i] eq 'noenter' )
		{
			(undef, $noenter) = splice(@opts,$i,2);
			last;
		}
	}
	if( $noenter )
	{
		push @opts, onKeyPress => 'return EPJS_block_enter( event )';
	}

	return $self->{repository}->xml->create_element( "input",
		name => $name,
		id => $name,
		value => $value,
		@opts );
}

=item $node = $xhtml->hidden_field( $name, $value, %opts );

Returns an XHTML hidden input field.

=cut

sub hidden_field
{
	my( $self, $name, $value, @opts ) = @_;

	return $self->{repository}->xml->create_element( "input",
		name => $name,
		id => $name,
		value => $value,
		type => "hidden",
		@opts );
}

=item $node = $xhtml->text_area_field( $name, $value, %opts )

Returns an XHTML textarea input.

=cut

sub text_area_field
{
	my( $self, $name, $value, @opts ) = @_;

	my $node = $self->{repository}->xml->create_element( "textarea",
		name => $name,
		id => $name,
		@opts );
	$node->appendChild( $self->{repository}->xml->create_text_node( $value ) );

	return $node;
}

=item $node = $xhtml->data_element( $name, $value, %opts )

Create a new element named $name containing a text node containing $value.

Options:
	indent - amount of whitespace to indent by

=cut

sub data_element
{
	my( $self, $name, $value, @opts ) = @_;

	my $indent;
	for(my $i = 0; $i < @opts; $i+=2)
	{
		if( $opts[$i] eq 'indent' )
		{
			(undef, $indent ) = splice(@opts,$i,2);
			last;
		}
	}

	my $node = $self->{repository}->xml->create_element( $name, @opts );
	$node->appendChild( $self->{repository}->xml->create_text_node( $value ) );

	if( defined $indent )
	{
		my $f = $self->{repository}->xml->create_document_fragment;
		$f->appendChild( $self->{repository}->xml->create_text_node(
			"\n"." "x$indent
			) );
		$f->appendChild( $node );
		return $f;
	}

	return $node;
}

=item $utf8_string = $xhtml->to_xhtml( $node, %opts )

Returns $node as valid XHTML.

=cut

sub to_xhtml
{
	my( $self, $node, %opts ) = @_;

	my $xml = $self->{repository}->xml;

	my @n = ();
	if( $xml->is( $node, "Element" ) )
	{
		my $tagname = $node->localName; # ignore prefixes

		$tagname = lc($tagname);

		push @n, '<', $tagname;
		my $nnm = $node->attributes;
		my $seen = {};

		if( $tagname eq "html" )
		{
			push @n, ' xmlns="http://www.w3.org/1999/xhtml"';
		}

		foreach my $i ( 0..$nnm->length-1 )
		{
			my $attr = $nnm->item($i);
			# strip all namespace definitions
			next if $attr->nodeName =~ /^xmlns/;
			my $name = $attr->localName;

			next if( exists $seen->{$name} );
			$seen->{$name} = 1;

			my $value = $attr->nodeValue;
			utf8::decode($value) unless utf8::is_utf8($value);
			$value =~ s/&/&amp;/g;
			$value =~ s/</&lt;/g;
			$value =~ s/>/&gt;/g;
			$value =~ s/"/&quot;/g;
			push @n, ' ', $name, '="', $value, '"';
		}

		if( $node->hasChildNodes )
		{
			push @n, '>';
			foreach my $kid ( $node->childNodes )
			{
				push @n, $self->to_xhtml( $kid, %opts );
			}
			push @n, '</', $tagname, '>';
		}
		elsif( $EPrints::XHTML::COMPRESS_TAG{$tagname} )
		{
			push @n, ' />';
		}
		elsif( $tagname eq "script" )
		{
			push @n, '>// <!-- No script --></', $tagname, '>';
		}
		else
		{
			push @n, '></', $tagname, '>';
		}
	}
	elsif( $xml->is( $node, "DocumentFragment" ) )
	{
		foreach my $kid ( $node->getChildNodes )
		{
			push @n, $self->to_xhtml( $kid, %opts );
		}
	}
	elsif( $xml->is( $node, "Document" ) )
	{
		push @n, $self->to_xhtml( $node->documentElement, %opts );
	}
	elsif( $xml->is( 
			$node, 
			"Text", 
			"Comment",
			"CDATASection", 
			"ProcessingInstruction",
			"EntityReference" ) )
	{
		push @n, $node->toString; 
		utf8::decode($n[$#n]) unless utf8::is_utf8($n[$#n]);
	}
	else
	{
		print STDERR "EPrints::XHTML: Not sure how to turn node type ".ref($node)." into XHTML.\n";
	}

	return wantarray ? @n : join('', @n);
}

=item $string = $xhtml->to_text_dump( $tree, %opts )

Dumps the XHTML contents of $tree as a utf8 string, stripping tags and converting common HTML layout elements into their plain-text equivalent.

Options:

	width - word-wrap after the given number of columns
	show_links - see below
	preformatted - equivalent to wrapping $tree in <pre></pre>

XHTML elements are removed with the following exceptions:

<br /> is replaced by a newline.

<p>...</p> will have a blank line above and below.

<img /> is replaced with the content of the I<alt> attribute.

<hr /> will insert a line of dashes if B<width> is set.

<a href="foo">bar</a> will be replaced by "bar <foo>" if B<show_links> is set.

=cut

######################################################################

sub to_text_dump
{
	my( $self, $node, %opts ) = @_;

	my $width = exists $opts{width} ? $opts{width} : undef;
	my $show_links = exists $opts{show_links} ? $opts{show_links} : 0;
	my $pre = exists $opts{preformatted} ? $opts{preformatted} : 0;

	my $str = "";
	$self->_to_text_dump( \$str, $node, $width, $pre, $show_links );
	utf8::decode($str) unless utf8::is_utf8($str);

	return $str;
}

sub _to_text_dump
{
	my( $self, $str, $node, $width, $pre, $show_links ) = @_;

	if( $self->{repository}->{xml}->is( $node, 'Text', 'CDataSection' ) )
	{
		my $v = $node->nodeValue();
		$v =~ s/[\s\r\n\t]+/ /g unless( $pre );
		$$str .= $v;
		return;
	}
	elsif( $self->{repository}->{xml}->is( $node, 'NodeList' ) )
	{
# Hmm, a node list, not a node.
		for( my $i=0 ; $i<$node->length ; ++$i )
		{
			$self->_to_text_dump(
					$str,
					$node->item( $i ), 
					$width,
					$pre,
					$show_links );
		}
		return;
	}

	my $name = lc $node->localName();

	# empty tags
	if( $name eq 'hr' )
	{
		# <hr /> only makes sense if we are generating a known width.
		$$str .= "\n"."-"x$width."\n" if $width;
		return;
	}
	elsif( $name eq 'br' )
	{
		$$str .= "\n";
		return;
	}

	my $contents = "";
	for( $node->childNodes )
	{
		$self->_to_text_dump( 
				\$contents,
				$_,
				$width, 
				( $pre || $name eq "pre" || $name eq "mail" ),
				$show_links );
	}

	# Handle wrapping block elements if a width was set.
	if( $width && ( $name eq "p" || $name eq "mail" ) )
	{
		$contents = EPrints::Utils::wrap_text( $contents, $width );
	}

	if( $name eq "fallback" )
	{
		$contents = "*".$contents."*";
	}
	elsif( $name eq "p" )
	{
		$contents =~ s/^(?:\n\n)?/\n\n/ if $$str !~ /\n\n$/;
		$contents =~ s/(?:\n)?$/\n/;
	}
	elsif( $name eq "img" )
	{
		$contents = $node->getAttribute( "alt" );
		$contents = "" if !defined $contents;
	}
	elsif( $name eq "a" )
	{
		if( $show_links )
		{
			my $href = $node->getAttribute( "href" );
			$contents .= " <$href>" if( defined $href );
		}
	}

	$$str .= $contents;

	return;
}

=item $page = $xhtml->page( $map, %opts )

Returns an EPrints::Page object describing an XHTML page filled out with the templates provided in $map.

$map is a hash of XHTML DOM fragments. At least "title" and "page" should be defined. Use "links" to add items to the header.

Option "page_id" set's the XML id of the <body> to be "page_YOURID". Useful when you want to use CSS to tweak elements on one page only.

Option "template" uses a different template to "default.xml".

=cut


sub page
{
	my( $self, $map, %options ) = @_;

	# This first bit is a really heinous hack, back it provides two really useful
	# functions, the contextual phrase editor and the "mainonly" feature making pages
	# easy to embed.
	
	unless( $self->{repository}->{offline} || !defined $self->{repository}->{query} )
	{
		my $mo = $self->{repository}->param( "mainonly" );
		if( defined $mo && $mo eq "yes" )
		{
			return EPrints::Page::DOM->new( $self->{repository}, $map->{page}, add_doctype=>0 );
		}

		my $dp = $self->{repository}->param( "edit_phrases" );
		# phrase debugging code.

		if( defined $dp && $dp eq "yes" )
		{
			my $current_user = $self->{repository}->current_user;	
			if( defined $current_user && $current_user->allow( "config/edit/phrase" ) )
			{
				my $phrase_screen = $self->{repository}->plugin( "Screen::Admin::Phrases",
		  			phrase_ids => [ sort keys %{$self->{repository}->{used_phrases}} ] );
				$map->{page} = $self->{repository}->xml->create_document_fragment;
				my $url = $self->{repository}->get_full_url;
				my( $a, $b ) = split( /\?/, $url );
				my @parts = ();
				foreach my $part ( split( "&", $b ) )	
				{
					next if( $part =~ m/^edit(_|\%5F)phrases=yes$/ );
					push @parts, $part;
				}
				$url = $a."?".join( "&", @parts );
				my $div = $self->{repository}->xml->create_element( "div", style=>"margin-bottom: 1em" );
				$map->{page}->appendChild( $div );
				$div->appendChild( $self->{repository}->html_phrase( "lib/session:phrase_edit_back",
					link => $self->{repository}->render_link( $url ),
					page_title => $self->{repository}->clone_for_me( $map->{title},1 ) ) );
				$map->{page}->appendChild( $phrase_screen->render );
				$map->{title} = $self->{repository}->html_phrase( "lib/session:phrase_edit_title",
					page_title => $map->{title} );
			}
		}
	}



	
	if( $self->{repository}->config( "dynamic_template","enable" ) )
	{
		if( $self->{repository}->can_call( "dynamic_template", "function" ) )
		{
			$self->{repository}->call( [ "dynamic_template", "function" ],
				$self->{repository},
				$map );
		}
	}

	my $pagehooks = $self->{repository}->config( "pagehooks" );
	$pagehooks = {} if !defined $pagehooks;
	my $ph = $pagehooks->{$options{page_id}} if defined $options{page_id};
	$ph = {} if !defined $ph;
	if( defined $options{page_id} )
	{
		$ph->{bodyattr}->{id} = "page_".$options{page_id};
	}

	# only really useful for head & pagetop, but it might as
	# well support the others

	foreach( keys %{$map} )
	{
		next if( !defined $ph->{$_} );

		my $pt = $self->{repository}->xml->create_document_fragment;
		$pt->appendChild( $map->{$_} );
		my $ptnew = $self->{repository}->clone_for_me(
			$ph->{$_},
			1 );
		$pt->appendChild( $ptnew );
		$map->{$_} = $pt;
	}

	if( !defined $options{template} )
	{
		if( $self->{repository}->get_secure )
		{
			$options{template} = "secure";
		}
		else
		{
			$options{template} = "default";
		}
	}

	my $parts = $self->{repository}->get_template_parts( 
				$self->{repository}->get_langid, 
				$options{template} );
	my @output = ();
	my $is_html = 0;

	foreach my $bit ( @{$parts} )
	{
		$is_html = !$is_html;

		if( $is_html )
		{
			push @output, $bit;
			next;
		}

		# either 
		#  print:epscript-expr
		#  pin:id-of-a-pin
		#  pin:id-of-a-pin.textonly
		#  phrase:id-of-a-phrase
		my( $type, $rest ) = split /:/, $bit, 2;

		if( $type eq "print" )
		{
			my $result = EPrints::XML::to_string( EPrints::Script::print( $rest, { session=>$self->{repository} } ), undef, 1 );
			push @output, $result;
			next;
		}

		if( $type eq "phrase" )
		{	
			push @output, EPrints::XML::to_string( $self->{repository}->html_phrase( $rest ), undef, 1 );
			next;
		}

		if( $type eq "pin" )
		{	
			my( $pinid, $modifier ) = split /:/, $rest, 2;
			if( defined $modifier && $modifier eq "textonly" )
			{
				my $text;
				if( defined $map->{"utf-8.".$pinid.".textonly"} )
				{
					$text = $map->{"utf-8.".$pinid.".textonly"};
				}
				elsif( defined $map->{$pinid} )
				{
					# don't convert href's to <http://...>'s
					$text = EPrints::Utils::tree_to_utf8( $map->{$pinid}, undef, undef, undef, 1 ); 
				}

				# else no title
				next unless defined $text;

				# escape any entities in the text (<>&" etc.)
				my $xml = $self->{repository}->xml->create_text_node( $text );
				push @output, EPrints::XML::to_string( $xml, undef, 1 );
				EPrints::XML::dispose( $xml );
				next;
			}
	
			if( defined $map->{"utf-8.".$pinid} )
			{
				push @output, $map->{"utf-8.".$pinid};
			}
			elsif( defined $map->{$pinid} )
			{
#EPrints::XML::tidy( $map->{$pinid} );
				push @output, EPrints::XML::to_string( $map->{$pinid}, undef, 1 );
			}
		}

		# otherwise this element is missing. Leave it blank.
	
	}

	return EPrints::Page::Text->new( $self->{repository}, join( "", @output ) );
}

=item $node = $xhtml->tabs( $labels, $contents, %opts )

Render a tabbed box where:

 labels - an array of label XHTML fragments
 contents - an array of content XHTML fragments

Options:

 base_url - the link to follow under non-JS (default = current URL)
 basename - prefix for tab identifiers (default = "ep_tabs")

=cut

sub tabs
{
	my( $self, $labels, $contents, %opts ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;

	my $frag = $xml->create_document_fragment;

	my $base_url = exists($opts{base_url}) ? $opts{base_url} : $repo->current_url( query => 1 );
	my $basename = exists($opts{basename}) ? $opts{basename} : "ep_tabs";

	# our special parameter
	my $q_current = $basename."_current";

	$base_url = URI->new( $base_url );
	{
		# strip our parameter from the base URL
		my @q = $base_url->query_form;
		for(reverse 0..$#q)
		{
			next if $_ % 2;
			splice(@q, $_, 2) if $q[$_] eq $q_current;
		}
		$base_url->query_form( @q );
	}

	# render the current page according to the request (javascript might alter
	# the actual page shown)
	my $current = 0;
	if( defined($repo->param( $q_current )) )
	{
		$current = $repo->param( $q_current );
	}

	my $tab_block = $xml->create_element( "div", class=>"ep_only_js" );	
	$frag->appendChild( $tab_block );

	my $panel = $xml->create_element( "div", 
			id => $basename."_panels",
			class => "ep_tab_panel" );
	$frag->appendChild( $panel );

	my %labels;
	my %links;
	for(0..$#$labels)
	{
		$labels{$_} = $labels->[$_];

		my $link = $base_url->clone();
		$link->query_form(
			$link->query_form,
			$q_current => $_,
		);
		$link->fragment( $basename."_panel_".$_ );
		$links{$_} = $link;

		my $inner_panel = $xml->create_element( "div", 
			id => $basename."_panel_".$_,
		);
		if( $_ != $current )
		{
			# padding for non-javascript enabled browsers
			$panel->appendChild( $xml->create_element( "div",
				class=>"ep_no_js",
				style => "height: 1em",
			) );
			$inner_panel->setAttribute( class => "ep_no_js" );
		}
		$panel->appendChild( $inner_panel );
		$inner_panel->appendChild( $contents->[$_] );
	}

	$tab_block->appendChild( 
		$repo->render_tabs( 
			id_prefix => $basename,
			current => $current,
			tabs => [0..$#$labels],
			labels => \%labels,
			links => \%links,
		));

	return $frag;
}

######################################################################
=pod

=back

=cut
######################################################################

1;
