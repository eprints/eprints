
package EPrints::Session;

use EPrints::Repository;
our @ISA = qw( EPrints::Repository );

sub get_session_language { EPrints::Repository::get_session_language( @_ ); }
sub best_language { EPrints::Repository::best_language( @_ ); }

sub EPrints::Session::new
{
	my( $class, $mode, $repository_id, $noise, $nocheckdb ) = @_;
	my %opts = ( noise=>0, cgi=>1 );
	if( $noise ) { $opts{noise} = $noise; }
	if( defined $mode && $mode == 1 ) { $opts{cgi} = 0; }
	if( defined $mode && $mode == 2 ) { $opts{cgi} = 1; $opts{consume_post} = 0; }
	if( $nocheckdb ) { $opts{check_database} = 0; }

	my $ep = EPrints->new( cleanup=>0 ); 
	if( $opts{cgi} )
	{
		$ep->current_repository( %opts );
	}
	else
	{
		$ep->repository( $repository_id, %opts );
	}
}


1;
