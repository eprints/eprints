# Load mimemap from /etc/mime.types

foreach my $mime_types (
	$c->{base_path} . "/lib/mime.types",
	"/etc/mime.types",
	)
{
	if( open(my $fh, "<", $mime_types) )
	{
		while(defined(my $line = <$fh>))
		{
			next if $line =~ /^\s*#/;
			next if $line !~ /\S/;
			chomp($line);
			my( $mt, @ext ) = split /\s+/, $line;
			$c->{mimemap}->{$_} = $mt for @ext;
		}
		close($fh);
	}
}
