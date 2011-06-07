# Parse multipart/ MIME messages

package MIME::Multipart::Parser;

use File::Temp;
use constant MAX_LINE_SIZE => 8092;

use strict;

sub new
{
	my( $class, %opts ) = @_;

	return bless \%opts, $class;
}

sub parse
{
	my( $self, $fh, $boundary ) = @_;

	local $self->{_buffer} = "";

	my @parts;
	while(my $part = $self->read_part( $fh, $boundary ))
	{
		push @parts, $part;
	}

	return @parts;
}

sub read_line
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

sub read_part
{
	my( $self, $fh, $boundary ) = @_;

	local $_;

	my @headers;
	while(defined($_ = $self->read_line($fh)))
	{
		s/\r?\n$//;
		last if $_ eq "";
		$headers[$#headers] .= $_, next if s/^ //;
		push @headers, split ':', $_, 2;
	}
	return if !defined $_;

	my $tmpfile = File::Temp->new;

	my $le = "";
	while(defined($_ = $self->read_line($fh)))
	{
		last if /^--$boundary/;
		syswrite($tmpfile, $le);
		s/(\r?\n)$//;
		$le = $1;
		syswrite($tmpfile, $_);
	}

	seek($tmpfile,0,0);

	return {
		headers => \@headers,
		tmpfile => $tmpfile,
	};
}

1;
