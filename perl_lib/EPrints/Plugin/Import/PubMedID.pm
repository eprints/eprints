package EPrints::Plugin::Import::PubMedID;

use strict;

use EPrints::Plugin::Import::TextFile;

our @ISA = qw/ EPrints::Plugin::Import::TextFile /;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "PubMed ID";
	$self->{visible} = "all";
	$self->{produce} = [ 'list/eprint', 'dataobj/eprint' ];

	return $self;
}

sub input_fh
{
	my( $plugin, %opts ) = @_;

	my @ids;

	my $fh = $opts{fh};
	while( <$fh> )
	{
		chomp;

		$_ =~ s/(['\\])/\\$1/g;
		my $cmd = "wget -O - 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed\\\&retmode=xml\\\&rettype=abstract\\\&id=$_' -q";
		my $pubmed_xml = `$cmd`;
		
		my $tmp_file = "/tmp/eprints.import.$$";
		open( TMP, ">$tmp_file" ) || die "Could not write to $tmp_file";
		print TMP $pubmed_xml;
		close TMP;

		my $pluginid = "Import::PubMedXML";
		my $sub_plugin = $plugin->{session}->plugin( $pluginid, parse_only=>$plugin->{parse_only}, scripted=>$plugin->{scripted} );

		my $list = $sub_plugin->input_file(
			dataset=>$opts{dataset},
			filename=>$tmp_file,
			user=>$opts{user},
		);

		if( -e $tmp_file )
		{
			unlink( $tmp_file );
		}

		push @ids, @{ $list->get_ids };

	}

	return EPrints::List->new( 
		dataset => $opts{dataset}, 
		session => $plugin->{session},
		ids=>\@ids );
}

1;
