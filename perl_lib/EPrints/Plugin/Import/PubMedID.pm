package EPrints::Plugin::Import::PubMedID;

use strict;

use EPrints::Plugin::Import::TextFile;
use LWP::Simple;

our @ISA = qw/ EPrints::Plugin::Import::TextFile /;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "PubMed ID";
	$self->{visible} = "all";
	$self->{produce} = [ 'list/eprint', 'dataobj/eprint' ];

	$self->{EFETCH_URL} = 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&retmode=xml&rettype=full&id=';

	return $self;
}

sub input_fh
{
	my( $plugin, %opts ) = @_;

	my @ids;

	my $fh = $opts{fh};
	while( my $pmid = <$fh> )
	{
		chomp $pmid;
		if( $pmid !~ /^[0-9]+$/ ) # primary IDs are always an integer
		{
			$plugin->warning( "Invalid ID: $pmid" );
			next;
		}

		# Fetch metadata for individual PubMed ID 
		# NB. EFetch utility can be passed a list of PubMed IDs but
		# fails to return all available metadata if the list 
		# contains an invalid ID
		my $pmxml = get( $plugin->{EFETCH_URL} . $pmid );
		if( defined $pmxml )
		{
			# Check record found
			if( $pmxml =~ /<ERROR>/ )
			{
				$plugin->warning( "No match: $pmid" );
				next;
			}

			# Write XML to temp file
			my $fh = new File::Temp;
			$fh->autoflush;
			print $fh $pmxml;

			# Hand over to Pubmed XML import plugin	
			my $pluginid = "Import::PubMedXML";
			my $sub_plugin = $plugin->{session}->plugin( $pluginid, parse_only => $plugin->{parse_only}, scripted => $plugin->{scripted} );

			my $list = $sub_plugin->input_file(
				dataset => $opts{dataset},
				filename => $fh->filename,
				user => $opts{user},
			);

			push @ids, @{ $list->get_ids };

			undef $fh;
		}
		else
		{
			$plugin->warning( "Could not access Pubmed EFETCH interface" );
		}

	}

	return EPrints::List->new( 
		dataset => $opts{dataset}, 
		session => $plugin->{session},
		ids=>\@ids );
}

1;
