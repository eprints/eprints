package SOAP::ISIWoK::Lite;

use base qw( SOAP::ISIWoK );

use strict;

sub new
{
	my ($class, %self) = @_;

	$self{endpoint} ||= SOAP::ISIWoK::WOKSEARCH_LITE_ENDPOINT;
	$self{service_type} ||= SOAP::ISIWoK::WOKSEARCH_LITE_SERVICE_TYPE;

	return $class->SUPER::new(%self);
}

1;
