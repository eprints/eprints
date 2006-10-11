
sub set_eprint_automatic_fields
{
	my( $eprint ) = @_;

	my $type = $eprint->get_value( "type" );
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

	if( $type eq "thesis" )
	{
		$eprint->set_value( "ispublished", "unpub" );
		# thesis are always unpublished.
	}

	my $date;
	if( $eprint->is_set( "date_issue" ) )
	{
		$date = $eprint->get_value( "date_issue" );
	} 
	elsif( $eprint->is_set( "date_sub" ) )
	{
		$date = $eprint->get_value( "date_sub" );
	}
	else
	{
	 	$date = $eprint->get_value( "datestamp" ); # worstcase
	}
	$eprint->set_value( "date_effective", $date );

	my @docs = $eprint->get_all_documents();
	my $textstatus = "none";
	my @finfo = ();
	if( scalar @docs > 0 )
	{
		$textstatus = "public";
		foreach my $doc ( @docs )
		{
			if( !$doc->is_public )
			{
				$textstatus = "restricted"
			}
			push @finfo, $doc->get_type.";".$doc->get_url;
		}
	}
	$eprint->set_value( "full_text_status", $textstatus );
	$eprint->set_value( "fileinfo", join( "|", @finfo ) );


}

