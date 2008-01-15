package EPrints::Plugin::Convert::PlainText;

=pod

=head1 NAME

EPrints::Plugin::Convert::PlainText - Convert documents to plain-text

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

# xml = ?
%EPrints::Plugin::Convert::PlainText::APPS = qw(
pdf		pdftotext
doc		antiword
htm		elinks
html		elinks
xml		elinks
ps		ps2ascii
txt		_special
);

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Plain text conversion";
	$self->{visible} = "all";

	return $self;
}

sub can_convert
{
	my ($plugin, $doc) = @_;

	# Get the main file name
	my $fn = $doc->get_main() or return ();

	my $mimetype = 'text/plain';

	my @type = ($mimetype => {
		plugin => $plugin,
		encoding => 'utf-8',
		phraseid => $plugin->html_phrase_id( $mimetype ),
	});

	if( $fn =~ /\.txt$/ )
	{
		return @type;
	}

	foreach my $ext ( keys %EPrints::Plugin::Convert::PlainText::APPS )
	{
		my $cmd_id = $EPrints::Plugin::Convert::PlainText::APPS{$ext};

		if( $fn =~ /\.$ext$/ )
		{
			if( $plugin->get_repository->can_execute( $cmd_id ) )
			{
				return @type;
			}
		}
	}
	
	return ();
}

sub export
{
	my ( $plugin, $dir, $doc, $type ) = @_;

	# What to call the temporary file
	my $main = $doc->get_main;
	
	my( $file_extension, $cmd_id );
	
	my $repository = $plugin->get_repository();

	# Find the app to use
	foreach my $ext ( keys %EPrints::Plugin::Convert::PlainText::APPS )
	{
		$file_extension = $ext;
		if( $main =~ /\.$ext$/i )
		{
			$cmd_id = $EPrints::Plugin::Convert::PlainText::APPS{$ext};
			last if $repository->can_execute( $cmd_id );
			last if $cmd_id eq "_special";
		}

		undef $cmd_id;
	}
	return () unless defined $cmd_id;
	
	my %files = $doc->files;
	my @txt_files;
	foreach my $filename ( keys %files )
	{
		my $tgt = $filename;
		next unless $tgt =~ s/\.$file_extension$/\.txt/;
		my $infile = EPrints::Utils::join_path( $doc->local_path, $filename );
		my $outfile = EPrints::Utils::join_path( $dir, $tgt );
		
		if( $file_extension eq 'txt' )
		{
			# PerlIO
			if( $PERL_VERSION gt v5.8.0 )
			{
				open( my $fh, "<:encoding(iso-8859-1)", $infile );
				open( my $fo, ">:utf8", $outfile );
				while(<$fh>) { print $fo $_ }
				close( $fh ); close( $fo );
			}
			# Unicode::String
			else
			{
				open( my $fh, "<", $infile );
				open( my $fo, ">", $outfile );
				while(<$fh>) { print $fo Unicode::String::latin1($_)->utf8; }
				close( $fh ); close( $fo );
			}
		}
		else
		{
			$repository->exec( $cmd_id,
				SOURCE_DIR => $doc->local_path,
				SOURCE => $infile,
				TARGET_DIR => $dir,
				TARGET => $outfile,
			);
		}
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
