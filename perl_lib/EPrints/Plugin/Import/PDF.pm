=head1 NAME

EPrints::Plugin::Import::PDF

=cut

package EPrints::Plugin::Import::PDF;

@ISA = qw( EPrints::Plugin::Import );

use strict;

our $MAX_SIZE = 1024 * 1024; # 1MB

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Import (PDF)";
	$self->{produce} = [qw( dataobj/eprint )];
	$self->{accept} = [qw( application/pdf )];
	$self->{advertise} = 0;
	$self->{actions} = [qw( metadata bibliography )];

	return $self;
}

sub input_fh
{
	my( $self, %opts ) = @_;

	my $session = $self->{session};
	my $filename = $opts{filename};

	my %flags = map { $_ => 1 } @{$opts{actions}};

	my $epdata = {
		documents => [{
			format => 'application/pdf',
			main => $filename,
			files => [{
				filename => $filename,
				filesize => (-s $opts{fh}),
				_content => $opts{fh}
			}],
		}],
	};

	if( $flags{metadata} || $flags{bibliography} )
	{
		my $filepath = "$opts{fh}";
		if( !-f $filepath ) # need to make a copy for our purposes :-(
		{
			$filepath = File::Temp->new;
			while(sysread($opts{fh},$_,4096))
			{
				syswrite($filepath,$_);
			}
			seek($opts{fh},0,0);
			seek($filepath,0,0);
		}

		my $cmd = sprintf("pdftotext -f 2 -enc UTF-8 -layout -htmlmeta %s -",
			quotemeta($filepath)
		);
		open(my $fh, "$cmd|") or die "Error in $cmd: $!";
		binmode($fh);
		my $buffer = "";
		while(<$fh>)
		{
			$buffer .= $_;
			last if length($buffer) > 10 * 1024 * 1024; # 10 MB
		}
		close($fh);

		if( $flags{metadata} )
		{
			$self->_parse_metadata( $buffer, %opts, epdata => $epdata );
		}

		if( $flags{bibliography} )
		{
			$self->_parse_bibliography( $buffer, %opts, epdata => $epdata );
		}
	}

	my @ids;
	my $dataobj = $self->epdata_to_dataobj( $opts{dataset}, $epdata );
	push @ids, $dataobj->id if $dataobj;

	return EPrints::List->new(
		session => $self->{session},
		dataset => $opts{dataset},
		ids => \@ids
	);
}

sub _parse_metadata
{
	my( $self, $buffer, %opts ) = @_;

	my $epdata = $opts{epdata};

	$buffer =~ /<title>([^<]+)<\/title>/;
	if( $1 )
	{
		$epdata->{title} = $1;
	}

	pos($buffer) = 0;
	while( $buffer =~ m/<meta name="([a-z]+)" content="([^"]+)">/ig )
	{
		my( $name, $value ) = (lc($1), $2);
		next if !$value;
		if( $name eq "keywords" )
		{
			$epdata->{keywords} = Encode::decode_utf8( $value );
		}
		elsif( $name eq "author" )
		{
			$epdata->{creators} = [];
			my @names = split /\s*,\s*/, Encode::decode_utf8( $value );
			for(@names)
			{
				s/\s*(\S+)$//;
				push @{$epdata->{creators}}, {
					name => { family => $1, given => $_, }
				};
			}
		}
	}
}

sub _parse_bibliography
{
	my( $self, $buffer, %opts ) = @_;

	my $epdata = $opts{epdata};

	$buffer =~ s/^.*?<pre>//s;
	$buffer =~ s/<\/pre>.*?$//s;

	$epdata->{documents} ||= [];

	my $ifh = File::Temp->new;
	syswrite($ifh, $buffer);
	sysseek($ifh, 0, 0);

	my $referencetext;
	my $ofh = File::Temp->new;
	$self->{repository}->exec( "txt2refs",
		SOURCE => "$ifh",
		TARGET => "$ofh",
	);
	sysseek($ofh, 0, 0);
	sysread($ofh, $buffer, (-s $ofh) > $MAX_SIZE ? $MAX_SIZE : -s $ofh);

	return if $buffer !~ /\S/;

	$epdata->{referencetext} = Encode::decode_utf8( $buffer );

	push @{$epdata->{documents}}, {
			format => "text/plain",
			content => "bibliography",
			main => "bibliography.txt",
#			relation => [{
#				type => EPrints::Utils::make_relation( "isVolatileVersionOf" ),
#				uri => $main_doc->internal_uri(),
#				},{
#				type => EPrints::Utils::make_relation( "isVersionOf" ),
#				uri => $main_doc->internal_uri(),
#				},{
#				type => EPrints::Utils::make_relation( "isPartOf" ),
#				uri => $main_doc->internal_uri(),
#			}],
			files => [{
				filename => "bibliography.txt",
				filesize => length( $buffer ),
				_content => \$buffer,
			}],
	};
}

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

