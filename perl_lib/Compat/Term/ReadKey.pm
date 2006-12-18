#####################################################################
#
# Compat::Term::ReadKey
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

B<Compat::Term::ReadKey> - Compatibility module for Term::ReadKey.

=head1 DESCRIPTION

This module provides a compatibility module for L<Term::ReadKey>, in
case the user can't install it. It will only change the terminal
mode on a linux-compiled Perl.

For full documentation of what these methods are supposed to do
see L<Term::ReadKey>.

=head1 SYNOPSIS

	require Compat::Term::ReadKey;
	
	print Term::ReadKey::GetTerminalSize( \*STDIN ), "\n";

=over 4

=cut

package Term::ReadKey;

use vars qw( @ISA @EXPORT );
use Exporter;
@ISA = qw( Exporter );

@EXPORT = qw(
	ReadMode
	ReadKey
	ReadLine
	GetTerminalSize
);

use vars qw( $STTY_NORMAL $STTY_RESTORE );

# Fetch the tty settings
sub _fetch_tty
{
	my $c = `stty -g`;
	chomp($c);
	return $c;
}

=item ReadMode MODE [, Filehandle]

Change the reading mode on the console (support for linux/stty only!).

=cut

sub ReadMode
{
	my( $mode, $fh ) = @_;	
	$fh ||= \*STDIN;

	return unless $^O eq 'linux';

	if( !defined $STTY_NORMAL )
	{
		$STTY_NORMAL = $STTY_RESTORE = &_fetch_tty;
	}

	if( $mode eq 'restore' or $mode eq '0' )
	{
		system "stty", $STTY_RESTORE;
	}
	if( $mode eq 'normal' or $mode eq '1' )
	{
		system "stty", $STTY_NORMAL;
	}
	if( $mode eq 'noecho' or $mode eq '2' )
	{
		$STTY_RESTORE = &_fetch_tty;
		system "stty", "-echo";
	}
	if( $mode eq 'raw' or $mode eq '4' )
	{
		$STTY_RESTORE = &_fetch_tty;
		system "stty", "-icanon", "eol", "\001";
	}
	if( $mode eq 'ultra-raw' or $mode eq '5' )
	{
		$STTY_RESTORE = &_fetch_tty;
		system "stty", "-icanon", "eol", "\001";
	}
}

# Read from console
sub _read
{
	my( $mode, $fh, $f ) = @_;
	$fh ||= \*STDIN;
	
	if( $mode == -1 )
	{
		ReadMode( 'raw' );
		my $r = &$f( $fh );
		ReadMode( 'restore' );
		return $r;
	}
	elsif( $mode > 0 )
	{
		my $r;
		eval {
			local $SIG{ALRM} = sub { die "alarm\n" };
			alarm $mode;
			$r = &$f($fh);
			alarm 0;
		};
		if( $@ ) {
			die unless $@ eq "alarm\n";
		}
		return $r;
	}
	return &$f($fh);
}

=item ReadKey MODE [, Filehandle]

Read a single character from the console.

=cut

sub ReadKey
{
	my( $mode, $fh ) = @_;	

	return _read( $mode, $fh, sub { getc(shift) });
}

=item ReadLine MODE [, Filehandle]

Read and return a line of input from the console.

=cut

sub ReadLine
{
	my( $mode, $fh ) = @_;	
	
	return _read( $mode, $fh, sub { my $fh = shift; return <$fh> });
}

=item GetTerminalSize [Filehandle]

Hard-coded as 80.

=cut

sub GetTerminalSize { 80 }

1;

__END__

=back
