#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;

my $dryrun;
my $license;
my $copyright;

GetOptions(
	dryrun => \$dryrun,
	"license=s" => \$license,
	"copyright=s" => \$copyright,
) or die "Error in options\n";

my( $path ) = @ARGV;
die "Usage: $0 [ path or filename ]\n" if !$path;

$path =~ s! /+$ !!x;

die "Can not read $path\n" if !-e $path || !-r $path;

my( @BOOTSTRAP, @LICENSE, @COPYRIGHT );

@BOOTSTRAP = <DATA>;

open(FH, "<", $license) or die "Error opening license $license: $!";
@LICENSE = <FH>;
close(FH);
push @LICENSE, "\n" if @LICENSE;

open(FH, "<", $copyright) or die "Error opening copyright $copyright: $!";
@COPYRIGHT = <FH>;
close(FH);
push @COPYRIGHT, "\n" if @COPYRIGHT;

if( -f $path )
{
	update_file( $path );
}
else
{
	update_dir( $path );
}

sub update_dir
{
	my( $dir ) = @_;

	opendir(my $dh, $dir) or die "Error opening $dir: $!";
	my @files = readdir($dh);
	closedir($dh);

	foreach my $filename (@files)
	{
		next if $filename =~ /^\./;
		$filename = "$dir/$filename";
		if( -f $filename )
		{
			open(FH,"<",$filename) or die "Error opening $filename: $!";
			my $shebang = <FH>;
			close(FH);
			next if $filename !~ /\.pm|\.pl$/ && $shebang !~ /^#\S*\bperl\b/;
			update_file( $filename );
		}
		else
		{
			update_dir( $filename );
		}
	}
}

sub update_file
{
	my( $filename ) = @_;

	open(FH, "<", $filename) or die "Error reading $filename: $!\n";
	my @lines = <FH>;
	close(FH);

	# strip old-style __COPYRIGHT__ ... __LICENSE__
	while(1)
	{
		my $start = 0;
		my $end = 0;

		$start++ while $start < @lines && $lines[$start] !~ /__COPYRIGHT__/;
		$end++ while $end < @lines && $lines[$end] !~ /__LICENSE__/;
		last if $start == @lines || $end == @lines;

		splice(@lines,$start,($end-$start)+1);
	}

	# strip __GENERICPOD__
	@lines = grep { $_ !~ /^__GENERICPOD__/ } @lines;

	# add a NAME header if needed
	if( !grep { /^=head1 NAME/ } @lines )
	{
		my( $class ) = grep { /^package/ } @lines;
		if( $class )
		{
			$class =~ s/^package\s+(\S+);/$1/;
			splice(@lines,0,0,"=head1 NAME\n","\n",$class,"\n","=cut\n","\n");
		}
	}

	# add =head1 COPYRIGHT if needed
	if( !grep { $_ =~ /^=head1\s+COPYRIGHT/ } @lines )
	{
		my $start = 0;
		$start++ while $start < @lines && $lines[$start] !~ /__DATA__/;

		# if not at end and need =cut add a =cut after the copyright
		if(
			$start < @lines &&
			$lines[$start-1] !~ /^=cut\b/ &&
			$lines[$start-2] !~ /^=cut\b/
		  )
		{
			splice(@lines,$start,0,"=cut\n","\n");
		}

		splice(@lines,$start,0,@BOOTSTRAP);
	}

	# add new COPYRIGHT and LICENSE
	my $start = 0;
	my $end = 0;
	while(1)
	{
		$start++ while $start < @lines && $lines[$start] !~ /^=for COPYRIGHT BEGIN/;
		$end++ while $end < @lines && $lines[$end] !~ /^=for COPYRIGHT END/;
		last if $start == @lines || $end == @lines; # wasn't found
		splice(@lines,$start+1,$end-$start-1,"\n",@COPYRIGHT);
		$start = $end = $start + @COPYRIGHT + 1;
	}
	$start = $end = 0;
	while(1)
	{
		$start++ while $start < @lines && $lines[$start] !~ /^=for LICENSE BEGIN/;
		$end++ while $end < @lines && $lines[$end] !~ /^=for LICENSE END/;
		last if $start == @lines || $end == @lines; # wasn't found
		splice(@lines,$start+1,$end-$start-1,"\n",@LICENSE);
		$start = $end = $start + @LICENSE + 1;
	}

	if( !$dryrun )
	{
		open(FH, ">", $filename) or die "Error writing to $filename: $!";
		print FH @lines;
		close(FH);
	}
	print "$filename\n";
}

__DATA__

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

=for COPYRIGHT END

=for LICENSE BEGIN

=for LICENSE END

