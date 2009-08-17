package EPrints::Plugin::Convert::IndexCodes;

use strict;

our @ISA = qw( EPrints::Plugin::Convert );

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Generate index codes";
	$self->{visible} = "api";

	return $self;
}

sub can_convert
{
	my( $self, $doc, $type ) = @_;

	return () unless defined($type) && $type eq "indexcodes";

	my %types = $self->SUPER::can_convert( $doc, "text/plain" );
	return () unless exists($types{"text/plain"});

	return(
		$type => {
			plugin => $self,
		},
	);
}

sub export
{
	my( $self, $dir, $doc, $type ) = @_;

	# Find a plugin to extract text from $doc
	$type = "text/plain";
	my %types = $self->SUPER::can_convert( $doc, $type );
	EPrints::abort( "Can't find text conversion plugin" ) unless exists($types{$type});
	my $plugin = $types{$type}->{"plugin"};

	# Extract the text and read it all into $text (upto 4MB)
	my @files = $plugin->export( $dir, $doc, "text/plain" );

	my $text = "";
	foreach my $file (@files)
	{
		open( my $fh, "<:utf8", "$dir/$file" ) or die "Error opening $dir/$file: $!";
		while( $fh->read( $text, 4096, length($text) ) )
		{
			last if length($text) > 4 * 1024 * 1024;
		}
		close($fh);
		unlink("$dir/$file");
	}

	# Extract the code terms from $text
	my( $codes, $badwords ) = ( [], [] );
	if( $text )
	{
		( $codes, $badwords ) = EPrints::MetaField::Text::_extract_words( $self->{handle}, $text );
	}

	return () unless scalar(@$codes);

	# Write out an indexcodes.txt file containing all the terms
	open( my $fh, ">:utf8", "$dir/indexcodes.txt" ) or die "Error opening $dir/indexcodes.txt: $!";
	local $" = "\n";
	print $fh "@$codes";
	close( $fh );

	return( "indexcodes.txt" );
}

1;
