#!/usr/bin/perl -w

use FindBin;
use lib "$FindBin::Bin/../perl_lib";

=head1 NAME

static_site.pl - generate a static Web site from EPrints

=head1 SYNOPSIS

static_site.pl [OPTIONS] repository_id output_dir

=head1 OPTIONS

=over 8

=item --help

=item --man

=item --http_root

Relative path the generated site should live below.

=back

=cut

use EPrints;

use strict;

use Getopt::Long;
use Pod::Usage;

GetOptions(
	help => \(my $opt_help),
	man => \(my $opt_man),
	'http_root=s' => \(my $opt_http_root),
) or pod2usage( 2 );

pod2usage( 1 ) if $opt_help;
pod2usage( -exitstatus => 0, -verbose => 2 ) if $opt_man;
pod2usage( 2 ) if @ARGV != 2;

my $repo = EPrints->new->repository( $ARGV[0] )
	or die "Unknown repository '$ARGV[0]'\n";

my $output_dir = $ARGV[1];
	die "'$output_dir' is not a directory\n" if !-d $output_dir;
$output_dir =~ s! /+$ !!x;

$repo->{config}->{rel_path} = $opt_http_root;
$repo->{config}->{http_url} = $opt_http_root;

my $i = 0;

$repo->{preparing_static_page} = 1;

my $langid = $repo->get_langid;

{
	my @static_dirs = $repo->get_static_dirs( $langid );
	my %source_files = EPrints::Update::Static::scan_static_dirs( $repo, \@static_dirs );
	while(my( $name, $source ) = each %source_files)
	{
		my @path = split '/', $name;
		pop @path;
		foreach my $i (0..$#path)
		{
			mkdir( $output_dir . join('/', '', @path[0..$i]) );
		}
		if( $name =~ /\.xhtml$/ )
		{
			EPrints::Update::Static::copy_xhtml( $repo, $source, "$output_dir/$name", {} );
		}
		elsif( $name =~ /\.xpage$/ )
		{
			EPrints::Update::Static::copy_xpage( $repo, $source, "$output_dir/$name", {} );
		}
		else
		{
			EPrints::Update::Static::copy_plain( $source, "$output_dir/$name", {} );
		}
	}

	EPrints::Update::Static::update_auto_js(
			$repo,
			$output_dir,
			\@static_dirs
		);
	EPrints::Update::Static::update_auto_css(
			$repo,
			$output_dir,
			\@static_dirs
		);
}

my $list = $repo->dataset( "archive" )->search;
$list->map(sub {
	(undef, undef, my $eprint) = @_;

	print STDERR sprintf("eprint %.0f%%\r",
		100 * $i++ / $list->count
	);

	my $base = "$output_dir/".$eprint->id;
	mkdir($base) if !-d $base;

	my( $page, $title, $links, $template ) = $eprint->render_preview;
	$repo->write_static_page(
		$base . "/index",
		{
			title => $title,
			page => $page,
			head => $repo->make_doc_fragment,
			template => $repo->make_text( $template ),
		}
	);

	my $docs = $eprint->value( "documents" );
	$eprint->set_value( "documents", $docs );
	foreach my $doc (@$docs)
	{
		foreach my $file (@{$doc->value( "files" )})
		{
			my $target = join '/',
				$base,
				$doc->value( "pos" ),
				$file->value( "filename" );
			my $target_dir = $target;
			$target_dir =~ s/\/[^\/]+$//;
			EPrints::Platform::mkdir( $target_dir );
			open(my $fh, ">", $target);
			$file->get_file(sub {
				syswrite($fh, $_[0]);
			});
			close($fh);
		}
	}
	my %docs = map { $_->id => $_ } @$docs;
	foreach my $doc (@$docs)
	{
		foreach my $relation (@{$doc->value( "relation" )})
		{
			my $type = $relation->{type};
			$type =~ s/^.*\///;
			next if $type !~ s/^is(.+)Of/has$1/;
			my $docid = $relation->{uri};
			next if $docid !~ s# ^/id/document/ ##x;
			my $rdoc = $docs{$docid};
			next if !defined $rdoc;
			my $dbase = "$base/".$rdoc->value( "pos" ).".$type";
			EPrints::Platform::mkdir( $dbase );
			link(
				"$base/".$doc->value( "pos" )."/".$doc->value( "main" ),
				"$dbase/".$rdoc->value( "main" ),
			);
		}
	}
});
