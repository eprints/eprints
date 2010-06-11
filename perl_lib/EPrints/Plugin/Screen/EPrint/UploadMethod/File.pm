package EPrints::Plugin::Screen::EPrint::UploadMethod::File;

use EPrints::Plugin::Screen::EPrint::UploadMethod;

@ISA = qw( EPrints::Plugin::Screen::EPrint::UploadMethod );

use strict;

sub new
{
	my( $self, %params ) = @_;

	return $self->SUPER::new(
		flags => [
			metadata => "",
			media => "",
			bibliography => "",
		],
		appears => [
			{ place => "upload_methods", position => 200 },
		],
		%params );
}

sub from
{
	my( $self, $basename ) = @_;
	
	my $session = $self->{session};
	my $processor = $self->{processor};
	my $eprint = $processor->{eprint};
	my $flags = $self->param_flags( $basename );

	return if !$self->SUPER::from( $basename );

	my $epdata = $processor->{notes}->{epdata};

	my $filename = $epdata->{main};
	return if !defined $filename;

	my $list;
	if( scalar grep { $_ } values %$flags )
	{
		$list = $self->parse_and_import( $basename, $epdata );
		if( !defined($list) )
		{
			$processor->add_message( "warning", $self->html_phrase( "unsupported_format" ) );
		}
	}
	if( !defined $list )
	{
		my $doc = $eprint->create_subdataobj( "documents", $epdata );
		if( defined $doc )
		{
			$list = EPrints::List->new(
				session => $session,
				dataset => $doc->dataset,
				ids => [$doc->id]
			);
		}
	}

	if( !defined $list || $list->count == 0 )
	{
		$processor->add_message( "error", $session->html_phrase( "Plugin/InputForm/Component/Upload:create_failed" ) );
		return;
	}

	for(@{$list->ids})
	{
		$processor->{notes}->{upload_plugin}->{to_unroll}->{$_} = 1;
	}
}

1;
