
# To go in Rewrite:
# use EPrints::Apache::Beast;
# if( !-e $filename && -e "$filename.link" )
# {
# 	$r->set_handlers(PerlResponseHandler => \&EPrints::Apache::Beast::handler );
# }


package EPrints::Apache::Beast;

use EPrints::Apache::AnApache; # exports apache constants
use Honey;

sub handler
{
	my( $request ) = @_;

	my $filename = $request->filename();

	open( LINK, "$filename.link" );
	my $mimetype = <LINK>;
	my $oid = <LINK>;
	close LINK;
	chomp $mimetype;
	chomp $oid;

	EPrints::Apache::AnApache::header_out($request, "Content-type"=>$mimetype );
	my $honey = Honey->new( "hc-data", 8080 );
	print $honey->string_oid( $oid );
	$honey->print_error if( $honey->error );

	return OK;
}

1;


