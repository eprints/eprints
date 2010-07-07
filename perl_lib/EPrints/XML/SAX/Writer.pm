package EPrints::XML::SAX::Writer;

=pod

Based on XML::SAX::Writer by:
Robin Berjon, robin@knowscape.com

=cut

use vars qw( %DEFAULT_ESCAPE %COMMENT_ESCAPE $ESCAPE_REGEX $COMMENT_ESCAPE_REGEX );

%DEFAULT_ESCAPE = (
                    '&'     => '&amp;',
                    '<'     => '&lt;',
                    '>'     => '&gt;',
                    '"'     => '&quot;',
                    "'"     => '&apos;',
                  );

%COMMENT_ESCAPE = (
                    '--'    => '&#45;&#45;',
                  );

$ESCAPE_REGEX = join( '|', map { $_ = "\Q$_\E" } keys %DEFAULT_ESCAPE );
$ESCAPE_REGEX = qr/$ESCAPE_REGEX/;

$COMMENT_ESCAPE_REGEX = join( '|', map { $_ = "\Q$_\E" } keys %COMMENT_ESCAPE );
$COMMENT_ESCAPE_REGEX = qr/$COMMENT_ESCAPE_REGEX/;

use strict;

use XML::NamespaceSupport qw();

sub new
{
	my( $class, %self ) = @_;

    $self{Output}          ||= *{STDOUT}{IO};
    $self{QuoteCharacter}  ||= "'";

	if( ref($self{Output}) eq "SCALAR" )
	{
		$self{_output} = sub { ${$self{Output}} .= $_[1] };
	}
	else
	{
		$self{_output} = sub { print {$self{Output}} $_[1] };
	}

	return bless \%self, $class;
}

sub start_document
{
    my( $self, $data ) = @_;

    $self->{NSDecl} = [];
    $self->{NSHelper} = XML::NamespaceSupport->new({ xmlns => 1, fatal_errors => 0 });
    $self->{NSHelper}->push_context;
}

sub end_document
{
    my( $self, $data ) = @_;

    # we may need to do a little more here
    $self->{NSHelper}->pop_context;
}

sub start_element {
    my( $self, $data ) = @_;

    $self->_output_element;

    my $attr = $data->{Attributes};

    # fix the namespaces and prefixes of what we're receiving, in case
    # something is wrong
    if( $data->{NamespaceURI} )
	{
        my $uri = $self->{NSHelper}->getURI($data->{Prefix}) || '';
		# ns has precedence
        if ($uri ne $data->{NamespaceURI})
		{
            $data->{Prefix} = $self->{NSHelper}->getPrefix($data->{NamespaceURI}); # random, but correct
            $data->{Name} = $data->{Prefix} ? "$data->{Prefix}:$data->{LocalName}" : "$data->{LocalName}";
        }
    }
    elsif ($data->{Prefix}) { # we can't have a prefix and no NS
        $data->{Name}   = $data->{LocalName};
        $data->{Prefix} = '';
    }

    # create a hash containing the attributes so that we can ensure there is
    # no duplication. Also, we check that ns are properly declared, that the
    # Name is good, etc...
    my %attr_hash;
    foreach my $at (values %$attr)
	{
        next unless length $at->{Name}; # people have trouble with autovivification
        if( $at->{NamespaceURI} )
		{
            my $uri = $self->{NSHelper}->getURI( $at->{Prefix} );
            warn "Well formed error: prefix '$at->{Prefix}' is not bound to any URI" unless defined $uri;
			# ns has precedence
            if( defined $uri and $uri ne $at->{NamespaceURI} )
			{ 
                $at->{Prefix} = $self->{NSHelper}->getPrefix( $at->{NamespaceURI} ); # random, but correct
                $at->{Name} = $at->{Prefix} ? "$at->{Prefix}:$at->{LocalName}" : "$at->{LocalName}";
            }
        }
        elsif ($at->{Prefix}) { # we can't have a prefix and no NS
            $at->{Name}   = $at->{LocalName};
            $at->{Prefix} = '';
        }
        $attr_hash{$at->{Name}} = $at->{Value};
    }

    foreach my $nd (@{$self->{NSDecl}})
	{
        if ($nd->{Prefix})
		{
            $attr_hash{'xmlns:' . $nd->{Prefix}} = $nd->{NamespaceURI};
        }
        else
		{
            $attr_hash{'xmlns'} = $nd->{NamespaceURI};
        }
    }
    $self->{NSDecl} = [];

	# buffer the element opening tag
	my @output;
	push @output, "<", $data->{Name};
	while(my( $k, $v ) = each %attr_hash)
	{
		push @output, " ", $k, "=", $self->{QuoteCharacter}, $self->escape( $v ), $self->{QuoteCharacter}; 
    }

    $self->{BufferElement} = join '', @output;
    $self->{NSHelper}->push_context;
}

sub end_element
{
    my( $self, $data ) = @_;

    if( exists $self->{BufferElement} )
	{
		$self->output( delete($self->{BufferElement}) . ' />' );
    }
    else
	{
		$self->output( '</' . $data->{Name} . '>' );
    }

    $self->{NSHelper}->pop_context;
}

sub characters
{
    my( $self, $data ) = @_;

    $self->_output_element;

    my $char = $data->{Data};

    if( $self->{InCDATA} )
	{
        # we must scan for ]]> in the CDATA and escape it if it
        # is present by close--opening
        # we need to have buffer text in front of this...
        $char = join ']]>]]&lt;<![CDATA[', split ']]>', $char;
    }
    else
	{
        $char = $self->escape( $char );
    }
	
	$self->output( $char );
}

sub start_prefix_mapping
{
    my( $self, $data ) = @_;

    push @{$self->{NSDecl}}, $data;

    $self->{NSHelper}->declare_prefix($data->{Prefix}, $data->{NamespaceURI});
}

sub end_prefix_mapping
{
}

sub processing_instruction
{
    my( $self, $data ) = @_;

    $self->_output_element;
    $self->_output_dtd;

    $self->output( "<?$data->{Target} $data->{Data}?>" );
}

sub ignorable_whitespace
{
    my( $self, $data ) = @_;

    $self->_output_element;

	$self->output( $data->{Data} );
}

sub skipped_entity
{
    my( $self, $data ) = @_;

    $self->_output_element;
    $self->_output_dtd;

    my $ent;
    if ($data->{Name} =~ m/^%/) {
        $ent = $data->{Name} . ';';

    } elsif ($data->{Name} eq '[dtd]') {
	# ignoring

    } else {
        $ent = '&' . $data->{Name} . ';';
    }

	$self->output( $ent );
}

sub notation_decl
{
    my( $self, $data ) = @_;

    $self->_output_dtd;

    # I think that param entities are normalized before this
    my $not = "    <!NOTATION " . $data->{Name};
    if ($data->{PublicId} and $data->{SystemId}) {
        $not .= ' PUBLIC \'' . $self->escape($data->{PublicId}) . '\' \'' . $self->escape($data->{SystemId}) . '\'';
    }
    elsif ($data->{PublicId}) {
        $not .= ' PUBLIC \'' . $self->escape($data->{PublicId}) . '\'';
    }
    else {
        $not .= ' SYSTEM \'' . $self->escape($data->{SystemId}) . '\'';
    }
    $not .= " >\n";

    $self->output( $not );
}

sub unparsed_entity_decl
{
    my( $self, $data ) = @_;

    $self->_output_dtd;

    # I think that param entities are normalized before this
    my $ent = "    <!ENTITY " . $data->{Name};
    if ($data->{PublicId}) {
        $ent .= ' PUBLIC \'' . $self->escape($data->{PublicId}) . '\' \'' . $self->escape($data->{SystemId}) . '\'';
    }
    else {
        $ent .= ' SYSTEM \'' . $self->escape($data->{SystemId}) . '\'';
    }
    $ent .= " NDATA $data->{Notation} >\n";

    $self->output( $ent );
}

sub element_decl
{
    my( $self, $data ) = @_;

    $self->_output_dtd;

    # I think that param entities are normalized before this
    my $eld = "    <!ELEMENT " . $data->{Name} . ' ' . $data->{Model} . " >\n";

    $self->output( $eld );
}

sub attribute_decl
{
    my( $self, $data ) = @_;
    $self->_output_dtd;

    # to be backward compatible with Perl SAX 2.0
    $data->{Mode} = $data->{ValueDefault} 
      if not(exists $data->{Mode}) and exists $data->{ValueDefault};

    # I think that param entities are normalized before this
    my $atd = "      <!ATTLIST " . $data->{eName} . ' ' . $data->{aName} . ' ';
    $atd   .= $data->{Type} . ' ' . $data->{Mode} . ' ';
    $atd   .= $data->{Value} . ' ' if $data->{Value};
    $atd   .= " >\n";

    $self->output( $atd );
}

sub internal_entity_decl
{
    my( $self, $data ) = @_;

    $self->_output_dtd;

    # I think that param entities are normalized before this
    my $ent = "    <!ENTITY " . $data->{Name} . ' \'' . $self->escape($data->{Value}) . "' >\n";

	$self->output( $ent );
}

sub external_entity_decl
{
    my( $self, $data ) = @_;

    $self->_output_dtd;

    # I think that param entities are normalized before this
    my $ent = "    <!ENTITY " . $data->{Name};
    if ($data->{PublicId}) {
        $ent .= ' PUBLIC \'' . $self->escape($data->{PublicId}) . '\' \'' . $self->escape($data->{SystemId}) . '\'';
    }
    else {
        $ent .= ' SYSTEM \'' . $self->escape($data->{SystemId}) . '\'';
    }
    $ent .= " >\n";

    $self->output( $ent );
}

sub comment
{
    my( $self, $data ) = @_;

    $self->_output_element;
    $self->_output_dtd;

    $self->output( '<!--' . $self->escapeComment($data->{Data}) . '-->' );
}

sub start_dtd
{
    my( $self, $data ) = @_;

    my $dtd = '<!DOCTYPE ' . $data->{Name};
    if ($data->{PublicId}) {
        $dtd .= ' PUBLIC \'' . $self->escape($data->{PublicId}) . '\' \'' . $self->escape($data->{SystemId}) . '\'';
    }
    elsif ($data->{SystemId}) {
        $dtd .= ' SYSTEM \'' . $self->escape($data->{SystemId}) . '\'';
    }

    $self->{BufferDTD} = $dtd;
}

sub end_dtd
{
    my( $self, $data ) = @_;

    my $dtd;
    if( defined(delete $self->{BufferDTD}) )
	{
        $dtd = $self->{BufferDTD} . ' >';
    }
    else
	{
        $dtd = ' ]>';
    }
	$self->output( $dtd );
}

sub start_cdata
{
    my( $self, $data ) = @_;
    $self->_output_element;

    $self->{InCDATA} = 1;

	$self->output( '<![CDATA[' );
}

sub end_cdata
{
    my( $self, $data ) = @_;

    $self->{InCDATA} = 0;

    $self->output( ']]>' );
}

sub start_entity
{
    my( $self, $data ) = @_;

    $self->_output_element;
    $self->_output_dtd;

    my $ent;
    if ($data->{Name} eq '[dtd]') {
        # we ignore the fact that we're dealing with an external
        # DTD entity here, and prolly shouldn't write the DTD
        # events unless explicitly told to
        # this will prolly change
    }
    elsif ($data->{Name} =~ m/^%/) {
        $ent = $data->{Name} . ';';
    }
    else {
        $ent = '&' . $data->{Name} . ';';
    }

    $self->output( $ent );
}

sub end_entity
{
    my( $self, $data ) = @_;
    # depending on what is done above, we might need to do sth here
}

### SAX1 stuff ######################################################

sub xml_decl
{
    my( $self, $data ) = @_;

    # version info is compulsory, contrary to what some seem to think
    # also, there's order in the pseudo-attr
    my $xd = '';
    if ($data->{Version}) {
        $xd .= "<?xml version='$data->{Version}'";
        if ($data->{Encoding}) {
            $xd .= " encoding='$data->{Encoding}'";
        }
        if ($data->{Standalone}) {
            $xd .= " standalone='$data->{Standalone}'";
        }
        $xd .= '?>';
    }

    $self->output( $xd );
}

sub _output_element
{
    my( $self ) = @_;

    if( exists $self->{BufferElement} )
	{
		$self->output( delete($self->{BufferElement}) . '>' );
    }
}

sub _output_dtd
{
    my( $self ) = @_;

    if( exists $self->{BufferDTD} )
	{
        $self->output( delete($self->{BufferDTD}) . " [\n" );
    }
}

sub escape
{
	my( $self, $str ) = @_;

    $str =~ s/($ESCAPE_REGEX)/$DEFAULT_ESCAPE{$1}/oge;

    return $str;
}

sub escape_comment
{
	my( $self, $str ) = @_;

    $str =~ s/($COMMENT_ESCAPE_REGEX)/$COMMENT_ESCAPE{$1}/oge;

    return $str;
}

sub output
{
	&{$_[0]->{_output}};
}

1;
