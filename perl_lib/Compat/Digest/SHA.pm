=pod

=head1 NAME

Compat::Digest::SHA - Compatibility module for Digest::SHA

=head1 DESCRIPTION

Import L<Digest::SHA::PurePerl> into the L<Digest::SHA> namespace.

=cut

package Digest::SHA;

use Digest::SHA::PurePerl;
@ISA = qw( Digest::SHA::PurePerl );

1;
