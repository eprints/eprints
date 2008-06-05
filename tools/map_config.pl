#!/usr/bin/perl -w

my $dh;
my @files = ();
opendir( $dh, "/opt/eprints3/lib/defaultcfg/cfg.d" ) || die "Dammit";
while( my $file = readdir( $dh ) )
{
	push @files, $file;
}
closedir( $dh );

my $byfile = {};
my $byopt = {};

foreach my $file ( @files )
{
	my $fn = "/opt/eprints3/lib/defaultcfg/cfg.d/$file";
	open( F, $fn ) || die "dang $fn : $!";
	foreach my $line ( <F> )
	{
		chomp $line;
		if( $line =~ m/^\s*\$c->{([^}]+)}/ )
		{
			$byfile->{$file}->{$1} = 1;
			$byopt->{$1}->{$file} = 1;
		} 
	}	
	close F;
}

foreach my $file ( sort keys %$byfile )
{
	print "== $file ==\n";
	foreach my $opt ( sort keys %{$byfile->{$file}} )
	{
		print "* $opt\n";
	}
}
print "\n\n\n";

foreach my $opt ( sort keys %$byopt )
{
	print "* $opt = [[".join( "]], [[", sort keys %{$byopt->{$opt}})."]]\n";
}
