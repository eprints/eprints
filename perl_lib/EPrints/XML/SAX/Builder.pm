# $Id: Builder.pm 785 2009-07-16 14:17:46Z pajas $
#
# This is free software, you may use it and distribute it under the same terms as
# Perl itself.
#
# Copyright 2001-2003 AxKit.com Ltd., 2002-2006 Christian Glahn, 2006-2009 Petr Pajas
#
#

package EPrints::XML::SAX::Builder;

use strict;

use XML::NamespaceSupport;

sub new
{
	my( $class, %self ) = @_;

	$self{XML} = EPrints::XML->new(
		$self{repository}
	);
	$self{DOM} = $self{XML}->{doc};
    $self{Parent} = $self{DOM}->createDocumentFragment;
    $self{NamespaceStack} = XML::NamespaceSupport->new;

	$self{LAST_DOM} = $self{Parent};

	return bless \%self, $class;
}

sub result { $_[0]->{LAST_DOM}; }

sub repository {
	my( $self ) = @_;
	return $self->{repository};
}

sub _done {
    my ($self) = @_;

    delete $self->{NamespaceStack};
    delete $self->{Parent};
    delete $self->{DOM};
}

sub set_document_locator {
}

sub start_dtd {
  my ($self, $dtd) = @_;
  if (defined $dtd->{Name} and
      (defined $dtd->{SystemId} or defined $dtd->{PublicId})) {
    $self->{DOM}->createExternalSubset($dtd->{Name},$dtd->{PublicId},$dtd->{SystemId});
  }
}

sub end_dtd {
}

sub start_document {
    my ($self, $doc) = @_;

    $self->{NamespaceStack}->push_context;

    return ();
}

sub xml_decl {
    my $self = shift;
    my $decl = shift;

#    if ( defined $decl->{Version} ) {
#        $self->{DOM}->setVersion( $decl->{Version} );
#    }
#    if ( defined $decl->{Encoding} ) {
#        $self->{DOM}->setEncoding( $decl->{Encoding} );
#    }
    return ();
}

sub end_document {
    my ($self, $doc) = @_;

	$self->{DOM}->setDocumentElement( $self->{Parent}->firstChild );
	$self->{LAST_DOM} = $self->{DOM};

	$self->_done;
}

sub start_prefix_mapping {
    my $self = shift;
    my $ns = shift;

    $self->{USENAMESPACESTACK} = 1;

    $self->{NamespaceStack}->declare_prefix( $ns->{Prefix}, $ns->{NamespaceURI} );
    return ();
}


sub end_prefix_mapping {
    my $self = shift;
    my $ns = shift;
    $self->{NamespaceStack}->undeclare_prefix( $ns->{Prefix} );
    return ();
}


sub start_element {
    my ($self, $el) = @_;
    my $node;

	if( defined $el->{NamespaceURI} && $el->{NamespaceURI} ne "" && $self->{DOM}->can( "createElementNS" ) )
	{
		$node = $self->{DOM}->createElementNS( $el->{NamespaceURI}, $el->{Name} );
	}
	else
	{
		$node = $self->{DOM}->createElement( $el->{Name} );
	}

	$self->{Parent}->appendChild( $node );
    $self->{Parent} = $node;

    $self->{NamespaceStack}->push_context;

    # do attributes
    foreach my $key (keys %{$el->{Attributes}}) {
        my $attr = $el->{Attributes}->{$key};
        if (ref($attr)) {
			if( defined $attr->{NamespaceURI} && $attr->{NamespaceURI} ne "" && $node->can( "setAttributeNS" ) )
			{
				$node->setAttributeNS($attr->{NamespaceURI}, $attr->{Name}, $attr->{Value});
			}
			else
			{
				$node->setAttribute( $attr->{Name}, $attr->{Value} );
			}
        }
        else {
            $node->setAttribute($key => $attr);
        }
    }
    return ();
}

sub end_element {
    my ($self, $el) = @_;

    $self->{NamespaceStack}->pop_context;
    $self->{Parent} = $self->{Parent}->parentNode();
    return ();
}

sub start_cdata {
    my $self = shift;
    $self->{IN_CDATA} = 1;
    return ();
}

sub end_cdata {
    my $self = shift;
    $self->{IN_CDATA} = 0;
    return ();
}

sub characters {
    my ($self, $chars) = @_;

    unless ( defined $chars and defined $chars->{Data} ) {
        return;
    }

    my $node;

    if ( defined $self->{IN_CDATA} and $self->{IN_CDATA} == 1 ) {
        $node = $self->{DOM}->createCDATASection($chars->{Data});
    }
    else {
		$node = $self->{DOM}->createTextNode($chars->{Data});
    }

    $self->{Parent}->appendChild($node);

    return ();
}

sub comment {
    my ($self, $chars) = @_;
    my $comment;

    unless ( defined $chars and defined $chars->{Data} ) {
        return;
    }

    $comment = $self->{DOM}->createComment( $chars->{Data} );
    $self->{Parent}->appendChild($comment);

    return ();
}

sub processing_instruction {
    my ( $self,  $pi ) = @_;

    my $PI = $self->{DOM}->createPI( $pi->{Target}, $pi->{Data} );
    $self->{Parent}->appendChild( $PI );

    return ();
}

sub warning {
    my $self = shift;
    my $error = shift;
    # fill $@ but do not die seriously
    eval { $error->throw; };
}

sub error {
    my $self = shift;
    my $error = shift;
	$self->_done;
    $error->throw;
}

sub fatal_error {
    my $self = shift;
    my $error = shift;
	$self->_done;
    $error->throw;
}

1;

__END__
