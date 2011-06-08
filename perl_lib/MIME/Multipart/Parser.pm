package MIME::Multipart::Parser;

=head1 NAME

MIME::Multipart::Parser - parse multipart/mixed messages

=head1 SYNOPSIS

	use MIME::Multipart::Parser;
	
	my $parser = MIME::Multipart::Parser->new;
	
	my @parts = $parser->parse( $fh, $boundary );

=head1 DESCRIPTION

=head1 METHODS

=over 4

=cut

use File::Temp;
use HTTP::Headers;
use MIME::Base64;
use MIME::QuotedPrint;

use constant MAX_LINE_SIZE => 8092;

use strict;

sub new
{
	my( $class, %opts ) = @_;

	return bless \%opts, $class;
}

=item @parts = $parser->parse( $fh, $boundary )

Reads a MIME multipart message from $fh, divided by $boundary, and returns the parts as a list of L<MIME::Multipart::Part>s.

=cut

sub parse
{
	my( $self, $fh, $boundary ) = @_;

	local $self->{_buffer} = "";

	my @parts;
	while(my $part = $self->_read_part( $fh, $boundary ))
	{
		push @parts, $part;
	}

	return @parts;
}

sub _read_line
{
	my( $self, $fh ) = @_;

	use bytes;
	local $_;

	for($self->{_buffer})
	{
		while( length($_) < MAX_LINE_SIZE )
		{
			last if !sysread($fh, $_, MAX_LINE_SIZE, length($_));
		}

		return $_ =~ s#^((?:[^\n]*\n)|.+)##s ? $1 : undef;
	}
}

sub _read_part
{
	my( $self, $fh, $boundary ) = @_;

	local $_;

	my @headers;
	while(defined($_ = $self->_read_line($fh)))
	{
		s/\r?\n$//;
		last if $_ eq "";
		# rfc2822, section 3.5
		die "Cowardly refusing to treat overlength header: $headers[$#headers]"
			if length($headers[$#headers]) > 998;
		$headers[$#headers] .= $_, next if s/^ //;
		push @headers, split /\s*: ?/, $_, 2;
	}
	return if !defined $_; # hit EOF in headers

	# decode any Encoded-Words and normalise via split/join
	foreach my $i (grep { $_ % 2 } 0 .. $#headers )
	{
		my @parts = HTTP::Headers::Util::split_header_words( $headers[$i] );
		foreach my $part (@parts)
		{
			for(@$part)
			{
				s/=\?([^?]+)\?([^?]+)\?([^?]+)\?=/
					Encode::decode($1,
						lc($2) eq 'q' ?
							MIME::QuotedPrint::decode_qp( $3 ) :
							MIME::Base64::decode_base64( $3 )
					);
				/eg;
				$_ = Encode::decode_utf8( $_ );
			}
		}
		$headers[$i] = HTTP::Headers::Util::join_header_words( @parts );
	}

	my $headers = HTTP::Headers->new( @headers );
	my( $cte ) = $headers->remove_header( "Content-Transfer-Encoding" );

	my $tmpfile = File::Temp->new;
	binmode($tmpfile);

	my $decode_f;
	if( !defined($cte) || $cte =~ /^7bit|8bit|binary$/ )
	{
	}
	elsif( lc($cte) eq "base64" )
	{
		$decode_f = \&MIME::Base64::decode_base64;
	}
	elsif( lc($cte) eq "quoted-printable" )
	{
		$decode_f = \&MIME::QuotedPrint::decode_qp;
	}
	else
	{
		die( "Unknown or unsupported Content-Transfer-Encoding: $cte" );
	}

	my $le = "";
	while(defined($_ = $self->_read_line($fh)))
	{
		last if /^--$boundary/;
		syswrite($tmpfile, $le) if !defined $decode_f;
		s/(\r?\n)$//;
		$le = $1;
		syswrite($tmpfile, defined($decode_f) ? &$decode_f($_) : $_);
	}

	seek($tmpfile,0,0);

	return {
		headers => $headers,
		tmpfile => $tmpfile,
	};
}

1;
