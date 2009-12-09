package EPrints::Plugin::Export::JSON;

use EPrints::Plugin::Export::TextFile;

@ISA = ( "EPrints::Plugin::Export::TextFile" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my( $self ) = $class->SUPER::new( %opts );

	$self->{name} = "JSON";
	$self->{accept} = [ 'list/*', 'dataobj/*' ];
	$self->{visible} = "all";
	$self->{suffix} = ".js";
	$self->{mimetype} = "text/javascript; charset=utf-8";
	$self->{arguments} = { jsonp => undef };

	return $self;
}


sub _header
{
	my( $self, %opts ) = @_;

	my $jsonp = $opts{jsonp};
	if( defined $jsonp )
	{
		$jsonp =~ s/[^=A-Za-z0-9_]//g;
		return "$jsonp(";
	}

	return "";
}

sub _footer
{
	my( $self, %opts ) = @_;

	my $jsonp = $opts{jsonp};
	if( defined $jsonp )
	{
		return ");\n";
	}
	return "";
}

sub output_list
{
	my( $self, %opts ) = @_;

	my $r = [];
	my $part;
	$part = $self->_header(%opts)."[\n";
	if( defined $opts{fh} )
	{
		print {$opts{fh}} $part;
	}
	else
	{
		push @{$r}, $part;
	}

	$opts{json_indent} = 1;
	my $first = 1;
	$opts{list}->map( sub {
		my( $session, $dataset, $dataobj ) = @_;
		my $part = "";
		if( $first ) { $first = 0; } else { $part = ",\n"; }
		$part .= $self->_epdata_to_json( $dataobj, 1 );
		if( defined $opts{fh} )
		{
			print {$opts{fh}} $part;
		}
		else
		{
			push @{$r}, $part;
		}
	} );

	$part= "\n]\n\n".$self->_footer(%opts);
	if( defined $opts{fh} )
	{
		print {$opts{fh}} $part;
	}
	else
	{
		push @{$r}, $part;
	}


	if( defined $opts{fh} )
	{
		return;
	}

	return join( '', @{$r} );
}

sub output_dataobj
{
	my( $self, $dataobj, %opts ) = @_;

	return $self->_header( %opts ).$self->_epdata_to_json( $dataobj, 1 ).$self->_footer( %opts );
}

sub _epdata_to_json
{
	my( $self, $epdata, $depth, $in_hash ) = @_;

	my $pad = "  " x $depth;
	my $pre_pad = $in_hash ? "" : $pad;
	

	if( !ref( $epdata ) )
	{
		
		if( !defined $epdata )
		{
			return "null"; # part of a compound field
		}
	
		$epdata =~ s/([\r\n])/ /g;
		$epdata =~ s/ +/ /g;
		$epdata =~ s/\s*$//;
	
		if( $epdata =~ /['\\]/ )
		{
			return $pre_pad . EPrints::Utils::js_string( $epdata );
		}
		else
		{
			return $pre_pad . "'$epdata'";
		}
	}
	elsif( ref( $epdata ) eq "ARRAY" )
	{
		return "$pre_pad\[\n" . join(",\n", map {
			$self->_epdata_to_json( $_, $depth + 1 )
		} @$epdata ) . "\n$pad\]";
	}
	elsif( ref( $epdata ) eq "HASH" )
	{
		return "$pre_pad\{\n" . join(",\n", map {
			$pad . "  " . $_ . ": " . $self->_epdata_to_json( $epdata->{$_}, $depth + 1, 1 )
		} keys %$epdata) . "\n$pad\}";
	}
	elsif( $epdata->isa( "EPrints::DataObj" ) )
	{
		my $subdata = {};

		foreach my $field ($epdata->get_dataset->get_fields)
		{
			next if !$field->get_property( "export_as_xml" );
			next if defined $field->{sub_name};
			my $value = $field->get_value( $epdata );
			next if !EPrints::Utils::is_set( $value );
			$subdata->{$field->get_name} = $value;
		}

		$subdata->{uri} = $epdata->uri;

		return $self->_epdata_to_json( $subdata, $depth + 1 );
	}
}


1;
