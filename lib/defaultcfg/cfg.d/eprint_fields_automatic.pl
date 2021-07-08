
$c->{set_eprint_automatic_fields} = sub
{
	my( $eprint ) = @_;

	my $type = $eprint->value( "type" );
	if( $type eq "monograph" || $type eq "thesis" )
	{
		unless( $eprint->is_set( "institution" ) )
		{
 			# This is a handy place to make monographs and thesis default to
			# your insitution
			#
			# $eprint->set_value( "institution", "University of Southampton" );
		}
	}

	if( $type eq "patent" )
	{
		$eprint->set_value( "ispublished", "pub" );
		# patents are always published!
	}

	if( $type eq "thesis" && !$eprint->is_set( "ispublished" ) )
	{
		$eprint->set_value( "ispublished", "unpub" );
		# thesis are usually unpublished.
	}

	my @docs = $eprint->get_all_documents();
	my $textstatus = "none";
	if( scalar @docs > 0 )
	{
		$textstatus = "public";
		foreach my $doc ( @docs )
		{
			if( !$doc->is_public )
			{
				$textstatus = "restricted";
				last;
			}
		}
	}
	$eprint->set_value( "full_text_status", $textstatus );
	
	#######
	#
	# Populate latitude longitude based on OpenCage API
	# get an API key at https://geocoder.opencagedata.com/api
	# you can use Geo::Coder::Googlev3 or Geo::Coder::OSM in the same way
	#
	# To use simply add something like:
	# <epc:if test="is_set($item.property('latitude'))">
	#  <img src="//maps.googleapis.com/maps/api/staticmap?size=512x255&amp;zoom=2&amp;maptype=terrain&amp;markers=color:red%7Clabel:S%7C{$item.property('latitude')},{$item.property('longitude')}" alt="{$item.property('where_shown_country')}" class="img-responsive img-rounded" />
	# </epc:if>
	# to your citation
	#######
	#if( $eprint->dataset->has_field( "your_address_field" ) && $eprint->is_set( "your_address_field" )){
	#	use Geo::Coder::OpenCage;
	#	
	#	my $my_api_key = "";
	#	my $ua = LWP::UserAgent->new( agent => "eprints geocoder");
	#	$ua->env_proxy;
	#	if ( $c->{"proxy"}) {
	#		$ua->proxy(['http', 'https', 'ftp'], $c->{"proxy"});
	#	}
	#	my $geocoder = Geo::Coder::OpenCage->new( api_key => $my_api_key, ua => $ua );
	#	my $location = $eprint->get_value( "your_address_field" );
	#	my $result = $geocoder->geocode(location => $location);
		
	#	push into latitude / longitude
	#	$eprint->set_value( "latitude", $result->{'results'}->[0]->{'geometry'}->{'lat'} );
	#	$eprint->set_value( "longitude", $result->{'results'}->[0]->{'geometry'}->{'lng'} );
	#}
};

