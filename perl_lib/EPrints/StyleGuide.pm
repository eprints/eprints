######################################################################
#
# EPrints::StyleGuide
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

package EPrints::StyleGuide;

use strict;
use warnings;

=head1 NAME

EPrints::StyleGuide - Style guide to writing EPrints modules and code

=head1 DESCRIPTION

EPrints has been under development for many years and has some fluff about the
place. For new programmers this document is intended as a 'style guide' to at
least keep the code and documentation consistent across new modules.

=head1 PROGRAMMING STYLE

=head2 Naming

	TYPE           EXAMPLE

	module         StyleGuide
	subroutine     get_value
	global var     AUTH_OK
	local var      $field_name

=head2 Subroutines

	sub get_value
	{
		my( $self, $arg1, $arg2 ) = @_;

		return $r;
	}

=head2 Conditionals

	if( ref($a) eq "ARRAY" )
	{
		return 0;
	}

=head2 Loops

	foreach my $field ( @fields )
	{
		foreach( @{$field->{ "lsd" }} )
		{
			$values{ $_ } = 1;
		}
	}

=head1 DOCUMENTATION

=head2 Name and License

Every EPrints module must start with the C<__LICENSE__> macro.

	######################################################################
	#
	# EPrints::StyleGuide
	#
	######################################################################
	#
	# __LICENSE__
	#
	######################################################################

=head2 Description

Below the license block the name, description and synopsis (a synopsis is an
example of usage). Lastly the METHODS title begins the section for inline
subroutine documentation.

	=head1 NAME

	EPrints::MyModule - A one line description of MyModule

	=head1 DESCRIPTION

	One or two paragraphs explaining the function of EPrints::MyModule.

	=head1 SYNOPSIS

		use EPrints::MyModule;

		my $obj = EPrints::MyModule->new( $opts );
		$obj->do_thing( $thingy );

	=head1 METHODS

	=over 4

	=cut

=head2 Methods

Each public subroutine should have POD documentation above it, with hashes to
separate it from the method above. A large module should probably be split into
different sections, e.g. "CONSTRUCTOR METHODS", "ACCESSOR METHODS", etc.
Private methods can be documented using Perl comments.

	######################################################################

	=item $objname = EPrints::StyleGuide->my_sub( $arg1, [$opt_arg2], \%opts )

	A description of what my_sub does and arguments it takes ($opt_arg2 is
	shown as optional by using brackets).

	A description of $arg1 if needed, along with an example:

		EPrints::StyleGuide->my_sub( "eprintid" );

		EPrints::StyleGuide->my_sub(
			$arg1,
			undef,
			{
				opt1 => $var1, # What is var1
				opt2 => $var2, # What is var2
			}
		);

	Further elaboration on the effect of $var2.

	=cut

	######################################################################

	sub my_sub
	{
		...
	}

=cut

1;
