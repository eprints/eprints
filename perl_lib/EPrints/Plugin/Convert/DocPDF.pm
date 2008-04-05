package EPrints::Plugin::Convert::DocPDF;

=pod

=head1 NAME

EPrints::Plugin::Convert::DocPDF - Convert documents to plain-text

=head1 DESCRIPTION

Uses the file extension to determine file type.

=cut

use strict;
use warnings;

use Carp;
use English;
use Unicode::String;

use EPrints::Plugin::Convert;
our @ISA = qw/ EPrints::Plugin::Convert /;

'antiwordpdf' => '$(antiword) -a a4 -m 8859-1 $(SOURCE) > $(TARGET)',

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Word to PDF conversion (via antiword)";
	$self->{visible} = "all";

	return $self;
}

sub can_convert
{
	my ($plugin, $doc) = @_;

	# Get the main file name
	my $fn = $doc->get_main() or return ();

	my $mimetype = 'application/pdf';

	my @type = ($mimetype => {
		plugin => $plugin,
		encoding => 'utf-8',
		phraseid => $plugin->html_phrase_id( $mimetype ),
	});

	if( $fn =~ /\.doc$/ )
	{
		if( $plugin->get_repository->can_execute( "antiword" ) )
		{
			return @type;
		}
	}
	
	return ();
}

sub export
{
	my ( $plugin, $dir, $doc, $type ) = @_;

	# What to call the temporary file
	my $main = $doc->get_main;
	
	my $repository = $plugin->get_repository();

	my %files = $doc->files;
	my @txt_files;
	foreach my $filename ( keys %files )
	{
		my $tgt = $filename;
		$tgt=~s/\.doc$/\.pdf/;
		my $infile = EPrints::Utils::join_path( $doc->local_path, $filename );
		my $outfile = EPrints::Utils::join_path( $dir, $tgt );
		$repository->exec( "antiwordpdf",
			SOURCE_DIR => $doc->local_path,
			SOURCE => $infile,
			TARGET_DIR => $dir,
			TARGET => $outfile,
		);
		EPrints::Utils::chown_for_eprints( $outfile );
	
		if( !-e $outfile || -z $outfile )
		{		
			if( $filename eq $doc->get_main )
			{
				return ();
			}
			else
			{
				next;
			}
		}

		if( $filename eq $doc->get_main ) 
		{
			unshift @txt_files, $tgt;
		} 
		else 
		{
			push @txt_files, $tgt;
		}
	}

	return @txt_files;
}

1;
