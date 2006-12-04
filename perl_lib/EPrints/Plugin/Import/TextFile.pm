package EPrints::Plugin::Import::TextFile;

use strict;

our @ISA = qw/ EPrints::Plugin::Import /;

$EPrints::Plugin::Import::DISABLE = 1;

use File::BOM;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{name} = "Base text input plugin: This should have been subclassed";
	$self->{visible} = "all";

	return $self;
}

sub input_file
{
	my( $plugin, %opts ) = @_;

	my $fh;
	if( $opts{filename} eq '-' )
	{
		$fh = *STDIN;
	}
	else
	{
		unless( open($fh, "<", $opts{filename}) )
		{
			print STDERR "Could not open file $opts{filename}: $!\n";
			return undef;
		}
	}
	$opts{fh} = $fh;

	if( $^V gt v5.8.0 and seek( $fh, 0, 1 ) )
	{
		# Strip the Byte Order Mark and set the encoding appropriately
		# See http://en.wikipedia.org/wiki/Byte_Order_Mark
		File::BOM::defuse($fh);

		# Read a line from the file handle and reset the fp
		my $start = tell( $fh );
		my $line = <$fh>;
		seek( $fh, $start, 0 )
			or die "Unable to reset file handle for crlf detection.";

		# If the line ends with return add the crlf layer
		if( $line =~ /\r$/ )
		{
			binmode( $fh, ":crlf" );
		}	
	}

	my $list = $plugin->input_fh( %opts );

	unless( $opts{filename} eq '-' )
	{
		close($fh);
	}

	return $list;
}

1;
