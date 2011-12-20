# legacy dynamic_template.pl
$c->add_trigger( EP_TRIGGER_DYNAMIC_TEMPLATE, sub {
	my %params = @_;

	my $repo = $params{repository};
	my $pins = $params{pins};

	if( $repo->config( "dynamic_template", "enable" ) )
	{
		if( $repo->can_call( "dynamic_template", "function" ) )
		{
			$repo->call( [ "dynamic_template", "function" ], $repo, $pins );
		}
	}
}, 10000);
