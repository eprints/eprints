package EPrints::Plugin::Import::ISIWoK;

use EPrints::Plugin::Import::TextFile;
@ISA = qw( EPrints::Plugin::Import::TextFile );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "ISI Web of Knowledge";
	$self->{visible} = "all";
	$self->{produce} = [ 'list/eprint' ];

	if( !EPrints::Utils::require_if_exists( "SOAP::ISIWoK" ) )
	{
		$self->{visible} = 0;
		$self->{error} = "Requires SOAP::ISIWoK";
	}

	return $self;
}

sub input_text_fh
{
	my( $self, %opts ) = @_;

	my $session = $self->{session};
	my $dataset = $opts{dataset};

	my @ids;

	my $fh = $opts{fh};
	my $query = join '', <$fh>;

	my $wok = SOAP::ISIWoK->new;

	my $xml = $wok->search( $query );

	foreach my $rec ($xml->getElementsByTagName( "REC" ))
	{
		my $epdata = $self->xml_to_epdata( $dataset, $rec );
		next if !scalar keys %$epdata;
		my $dataobj = $self->epdata_to_dataobj( $dataset, $epdata );
		push @ids, $dataobj->id if defined $dataobj;
	}

	return EPrints::List->new(
		session => $session,
		dataset => $dataset,
		ids => \@ids );
}

sub xml_to_epdata
{
	my( $self, $dataset, $rec ) = @_;

	my $epdata = {};

	my $node;

	( $node ) = $rec->findnodes( "item/item_title" );
	$epdata->{title} = $node->textContent if $node;

	if( !$node )
	{
		die "Expected to find item_title in: ".$rec->toString( 1 );
	}

	( $node ) = $rec->findnodes( "item/source_title" );
	if( $node )
	{
		$epdata->{publication} = $node->textContent;
		$epdata->{status} = "published";
	}

	foreach my $node ($rec->findnodes( "item/article_nos/article_no" ))
	{
		my $id = $node->textContent;
		if( $id =~ s/^DOI\s+// )
		{
			$epdata->{id_number} = $id;
		}
	}

	( $node ) = $rec->findnodes( "item/bib_pages" );
	$epdata->{pagerange} = $node->textContent if $node;

	( $node ) = $rec->findnodes( "item/bib_issue" );
	if( $node )
	{
		$epdata->{date} = $node->getAttribute( "year" ) if $node->hasAttribute( "year" );
		$epdata->{volume} = $node->getAttribute( "vol" ) if $node->hasAttribute( "vol" );
	}

	# 
	$epdata->{type} = "article";
	( $node ) = $rec->findnodes( "item/doctype" );
	if( $node )
	{
	}

	foreach my $node ($rec->findnodes( "item/authors/*" ))
	{
		if( $node->nodeName eq "fullauthorname" )
		{
			next if !$epdata->{creators};
			my( $family ) = $node->getElementsByTagName( "AuLastName" );
			my( $given ) = $node->getElementsByTagName( "AuFirstName" );
			$family = $family->textContent if $family;
			$given = $given->textContent if $given;
			$epdata->{creators}->[$#{$epdata->{creators}}]->{name} = {
				family => $family,
				given => $given,
			};
		}
		else
		{
			my $name = $node->textContent;
			my( $family, $given ) = split /,/, $name;
			push @{$epdata->{creators}}, {
				name => { family => $family, given => $given },
			};
		}
	}

	foreach my $node ($rec->findnodes( "item/keywords/*" ))
	{
		push @{$epdata->{keywords}}, $node->textContent;
	}
	$epdata->{keywords} = join ", ", @{$epdata->{keywords}} if $epdata->{keywords};

	( $node ) = $rec->findnodes( "item/abstract" );
	$epdata->{abstract} = $node->textContent if $node;

	# include the complete data for debug
	$epdata->{suggestions} = $rec->toString( 1 );

	return $epdata;
}

1;
