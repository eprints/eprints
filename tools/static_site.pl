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

my $verbose = 1;
my $views = 1;

GetOptions(
	help => \(my $opt_help),
	man => \(my $opt_man),
	'http_root=s' => \(my $opt_http_root),
	'verbose+' => \$verbose,
	'views!' => \$views,
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

my $xml_plugin = $repo->plugin( "Export::XML" );

# disable import/export/screen plugins
foreach my $type (qw( Import Export Screen ))
{
	foreach my $plugin ($repo->get_plugins( type => $type ))
	{
		$repo->{config}->{plugins}->{$plugin->get_id}->{params}->{disable} = 1;
	}
}
delete $repo->{config}->{plugins}->{"Screen"}->{params}->{disable};

$repo->_load_plugins;

my $i = 0;

$repo->{preparing_static_page} = 1;

my $langid = $repo->get_langid;

# static files
{
	warn "Writing static files\n" if $verbose > 1;

	my @static_dirs = $repo->get_static_dirs( $langid );
	my %source_files = EPrints::Update::Static::scan_static_dirs( $repo, \@static_dirs );
	while(my( $name, $source ) = each %source_files)
	{
		warn "copy $source $output_dir/$name\n" if $verbose > 2;
		EPrints::Update::Static::copy_file( $repo, $source, "$output_dir/$name", {} );
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

# views
if( $views )
{
	warn "Writing views\n" if $verbose > 1;
	$repo->cache_subjects;

	my $target = join "/", $output_dir, "view";

	my $views = $repo->config( "browse_views" );
	foreach my $view (@$views)
	{
		$view = EPrints::Update::Views->new(
			repository => $repo,
			view => $view,
		);
		$view->update_view_by_path(
			on_write => sub {
				print "Wrote: $_[0]\n" if $verbose > 1;
				generate_html( $_[0] );
				foreach my $v (@{$view->{variations}||[]})
				{
					if( $v eq "DEFAULT" )
					{
						generate_html( "$_[0].default" );
					}
					else
					{
						generate_html( "$_[0].$v" );
					}
				}
			},
			langid => $langid,
			do_menus => 1,
			do_lists => 1,
			target => $target );
	}

	EPrints::Update::Views::update_browse_view_list( $repo, "$target/index", $langid );
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
#	$repo->write_static_page(
#		$base . "/index",
#		{
#			title => $title,
#			page => $page,
#			head => $repo->make_doc_fragment,
#			template => $repo->make_text( $template ),
#		}
#	);
	generate_html( "$base/index",
		"utf-8.title" => scalar( $repo->xhtml->to_xhtml( $title ) ),
		"utf-8.page" => scalar( $repo->xhtml->to_xhtml( $page ) ),
		"utf-8.head" => scalar( $repo->xhtml->to_xhtml( $links ) ),
	);
	open(my $fh, ">:utf8", "$base/eprint.xml");
	$xml_plugin->output_dataobj( $eprint,
		dataset => $eprint->{dataset},
		fh => $fh,
	);
	close($fh);

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

sub generate_html
{
	my( $filepath, %parts ) = @_;

	my $dir = $filepath;
	$dir =~ s/\/[^\/]+$//;
	EPrints::Platform::mkdir( $dir );

	foreach my $part ( "title", "title.textonly", "page", "head", "template" )
	{
		next if defined $parts{"utf-8.$part"};
		$parts{"utf-8.$part"} = "";
		if(open(my $fh, "<:utf8", "$filepath.$part"))
		{
			local $/;
			$parts{"utf-8.$part"} = <$fh>;
			close($fh);
			unlink("$filepath.$part");
		}
	}

	$parts{"utf-8.head"} .= <<'EOH';
<meta http-equiv="content-type" content="text/html; charset=utf-8" />
EOH

	my $page = $repo->prepare_page( \%parts, page_id=>"static", template=>"default", );
	$page->write_to_file( "$filepath.html", {} );
}
