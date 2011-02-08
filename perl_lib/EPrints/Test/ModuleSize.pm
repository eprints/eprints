package EPrints::Test::ModuleSize;

=head1 NAME

EPrints::Test::ModuleSize - calculate the footprint of a module

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use Devel::Size;

use strict;

sub scan
{
	return _scan( "EPrints", {} );
}

sub _scan
{
	my( $name, $sizes ) = @_;

	no strict 'refs';
	while(my( $k, $v ) = each %{"${name}::"})
	{
		# class
		if( $k =~ s/::$// )
		{
			next if $k eq "SUPER";
			_scan( $name . "::" . $k, $sizes);
		}
		# glob
		else
		{
			$sizes->{$name} += Devel::Size::size( $v );
		}
	}

	return $sizes;
}

1;
