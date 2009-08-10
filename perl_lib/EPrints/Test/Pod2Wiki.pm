package EPrints::Test::Pod2Wiki;

=head1 NAME

EPrints::Test::Pod2Wiki - convert EPrints pod to MediaWiki

=head1 SYNOPSIS

	use EPrints::Test::Pod2Wiki;

	my $p = EPrints::Test::Pod2Wiki->new(
		wiki_index => "http://wiki.foo.org/index.php",
		username => "johnd",
		password => "xiPi00",
		);

	$p->update_page( "EPrints::Utils" );

=head1 DESCRIPTION

This module enables the integration of EPrints POD (documentation) and MediaWiki pages.

=head1 METHODS

=over 4

=cut

use Pod::Parser;
@ISA = qw( Pod::Parser );

use EPrints;
use LWP::UserAgent;
use Pod::Html;
use HTML::Entities;
use HTTP::Cookies;

use strict;

my $PREFIX = "Pod2Wiki=";
my $END_PREFIX = "End of Pod2Wiki";

=item EPrints::Test::Pod2Wiki->new( ... )

Create a new Pod2Wiki parser. Required options:

  wiki_index - URL of the MediaWiki "index.php" page
  username - MediaWiki username
  password - MediaWiki password

=cut

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	my $ua = LWP::UserAgent->new;

	$self->{_ua} = $ua;

	my $u = URI->new( $self->{wiki_index} );
	$u->query_form(
		title => "Special:Userlogin",
		action => "submitlogin",
		type => "login"
	);

	my $cookie_jar = HTTP::Cookies->new;
	$ua->cookie_jar( $cookie_jar );

	# log into the Wiki
	my $r = $ua->post( $u, [
		wpName => $opts{username},
		wpPassword => $opts{password},
		wpDomain => "eprints",
		wpLoginattempt => "Log in",
	]);

#print STDERR "$u\n", $r->headers->as_string, $r->content;

	return $self;
}

=item $ok = $pod->update_page( $package_name )

Update the MediaWiki page for $package_name.

=cut

sub update_page
{
	my( $self, $package_name ) = @_;

	_flush_seen(); # see method
	$self->{_out} = [ $self->_p2w_preamble() ];

	# locate the source file
	my $file = $self->_p2w_locate_package( $package_name );
	if( !-f $file )
	{
		print STDERR "Warning! Source file not found for $package_name: $file\n";
		return 0;
	}

	my $title = $self->_p2w_wiki_title( $package_name );

	# retrieve the current wiki page
	my $wiki_page = $self->_p2w_wiki_source( $title );

	# populate _wiki with any wiki content
	$self->_p2w_parse_wiki( $wiki_page );

	push @{$self->{_out}}, delete($self->{_wiki}->{"_preamble_"})
		if defined $self->{_wiki}->{"_preamble_"};

	# parse the file for POD statements
	$self->parse_from_file( $file );

	# make sure that there was a $END_PREFIX
	$self->command( "pod" );

	push @{$self->{_out}},
		"<!-- ${PREFIX}_postamble_ -->",
		"<!-- $END_PREFIX -->";

	push @{$self->{_out}}, delete($self->{_wiki}->{"_postamble_"})
		if defined $self->{_wiki}->{"_postamble_"};

	my $new_wiki_page = join "", @{$self->{_out}};
	if( $new_wiki_page ne $wiki_page )
	{
#print STDERR "Output:\n$new_wiki_page";
		my $u = URI->new( $self->{wiki_index} );
		$u->query_form(
			title => $title,
			action => "edit"
		);
		my $r = $self->{_ua}->get( $u );
		my( $edit_time ) = $r->content =~ /<input (.*?wpStarttime.*?)\/>/;
		$edit_time = $edit_time =~ /value=["']([^"']+)/;
		my( $edit_token ) = $r->content =~ /<input (.*?wpEditToken.*?)\/>/;
		($edit_token) = $edit_token =~ /value=["']([^"']+)/;
		my( $auto_summary ) = $r->content =~ /<input (.*?wpAutoSummary.*?)\/>/;
		($auto_summary) = $auto_summary =~ /value=["']([^"']+)/;
		$u->query_form(
			title => $title,
			action => "submit"
		);
		$r = $self->{_ua}->post( $u, [
			wpStarttime => $edit_time,
			wpEdittime => $edit_time,
			wpSection => "",
			wpTextbox1 => $new_wiki_page,
			wpSave => "Save page",
			wpEditToken => $edit_token,
			wpAutoSummary => $auto_summary,
		]);
print STDERR "Ok\n" if $r->code eq "302";
	}
	else
	{
print STDERR "Nothing changed\n";
	}
}

# preamble blurb for the Wiki output (placed in a comment)
sub _p2w_preamble
{
	my( $self ) = @_;

	my $blurb = <<EOC;
This page has been automatically generated from the EPrints source. Any wiki changes made between the '$PREFIX*' and '$END_PREFIX' comments will be lost.
EOC

	return (
		"<!-- ${PREFIX}_preamble_ \n$blurb -->",
		"[[Category:API]]",
		"<!-- $END_PREFIX -->\n",
	);
}

# returns the filename that package will use
sub _p2w_locate_package
{
	my( $self, $package_name ) = @_;

	my $perl_lib = $EPrints::SystemSettings::conf->{base_path} . "/perl_lib";
	my $file = $package_name;
	$file =~ s/::/\//g;
	$file = "$perl_lib/$file.pm";

	return $file;
}

# what title we should use based on the perl package name
sub _p2w_wiki_title
{
	my( $self, $package_name ) = @_;

#	$package_name =~ s/::/-/g;

	return "API_$package_name";
}

# retrieve the Wiki source page
sub _p2w_wiki_source
{
	my( $self, $title ) = @_;

	my $u = URI->new( $self->{wiki_index} );
	$u->query_form(
		title => $title,
		action => "raw",
	);

	my $r = $self->{_ua}->get( $u );

	return $r->is_success ? $r->content : "";
}

# parse the Wiki source and record any Wiki that may have been added to the
# basic POD translation
sub _p2w_parse_wiki
{
	my( $self, $content ) = @_;

	my %wiki;
	my $pod_section = "_preamble_";
	my $in_pod = 0;

	for($content) {
		pos($_) = 0;
		while(pos($_) < length($_))
		{
# start of a POD section
			if( /\G<!-- $PREFIX([^\s]+) .*?-->/sgoc )
			{
				$pod_section = $1;
				$in_pod = 1;
				next;
			}
# end of previous POD section
			if( $in_pod && m/\G<!-- $END_PREFIX -->/sgoc )
			{
				$in_pod = 0;
				next;
			}
# ignore POD
			$in_pod && /\G.+?<!--/sgc && (pos($_)-=4, next);
# capture Wiki content
			/\G(.+?)<!--/sgc && (pos($_)-=4, $wiki{$pod_section} .= $1, next);
# trailing stuff
			$in_pod && /\G.+/sgc && (next);
			/\G.+/sgc && ($wiki{$pod_section} .= $1, next);
			Carp::confess "Oops: got to end of parse loop and didn't match: '".substr($_,pos($_),40) . " ...'";
		}
	}

	foreach my $key (keys %wiki)
	{
		$wiki{$key} =~ s/^\n\n+/\n/;
		delete $wiki{$key} unless $wiki{$key} =~ /\S/;
	}

	$self->{_wiki} = \%wiki;
}

=item $parser->command( ... )

L<Pod::Parser> callback.

=cut

sub command
{
	my( $self, $cmd, $text, $line_num, $pod_para ) = @_;

	if( $self->{_p2w_pod_section} )
	{
		push @{$self->{_out}},
			"<!-- $END_PREFIX -->\n";
		my $key = $self->{_p2w_pod_section};
		if( $self->{_wiki}->{$key} )
		{
			push @{$self->{_out}},
				delete $self->{_wiki}->{$key};
		}
		$self->{_p2w_pod_section} = undef;
	}
	return if $cmd eq "pod";

	$text =~ s/\n+//g;
	my $key = EPrints::Utils::escape_filename( $text );
	my $ref = lc( _p2w_fragment_id( $text ) );
	$text = $self->interpolate( $text, $line_num );

	if( $cmd =~ /^head(\d+)/ )
	{
		$self->{_p2w_head_depth} = $1;
		my $eqs = "=" x $1;
		push @{$self->{_out}},
			"<!-- ${PREFIX}head_$ref -->",
			"$eqs$text$eqs\n";
		$self->{_p2w_pod_section} = "head_$ref";
	}
	elsif( $cmd eq "over" or $cmd eq "back" )
	{
	}
	elsif( $cmd eq "item" )
	{
		my $depth = $self->{_p2w_head_depth} || 0;
		++$depth;
		my $eqs = "=" x $depth;
		push @{$self->{_out}},
			"<!-- ${PREFIX}item_$ref -->",
			"$eqs$ref$eqs\n\n",
			"  $text\n\n";
		$self->{_p2w_pod_section} = "item_$ref";
	}
	else
	{
		$text =~ s/[\r\n]+$//s;
		push @{$self->{_out}},
			"<!-- ${PREFIX}$cmd -->",
			$text;
		$self->{_p2w_pod_section} = $cmd;
	}
}

=item $parser->verbatim( ... )

L<Pod::Parser> callback.

=cut

sub verbatim
{
	my( $self, $text, $line_num, $pod_para ) = @_;

	return unless $self->{_p2w_pod_section};
	chomp($text);
	$text = $self->interpolate( $text, $line_num );
	push @{$self->{_out}},
		$text;
}

=item $parser->textblock( ... )

L<Pod::Parser> callback.

=cut

sub textblock
{
	my( $self, $text, $line_num, $pod_para ) = @_;

	return unless $self->{_p2w_pod_section};
	chomp($text);
	$text = $self->interpolate( $text, $line_num );
	push @{$self->{_out}},
		$text;
}

=item $parser->interpolate( ... )

L<Pod::Parser> callback. Overloaded to also escape HTML entities.

=cut

sub interpolate
{
	my( $self, $text, $line_num ) = @_;

	$text = $self->SUPER::interpolate( $text, $line_num );
	# join wrapped lines together
	$text =~ s/([^\n])\n([^\s])/$1$2/g;
	# tabs = indented
	$text =~ s/\t/  /g;
	$text = HTML::Entities::encode_entities( $text, "<>&" );
	$text =~ s/\x00([a-z0-9]+)\x00([^\x00]+)\x00/<$1>$2<\/$1>/g;

	return $text;
}

=item $parser->interior_sequence( ... )

L<Pod::Parser> callback.

=cut

sub interior_sequence
{
	my( $self, $seq_cmd, $seq_arg, $pod_seq ) = @_;

	# shouldn't happen
	return unless $self->{_p2w_pod_section};

	return "'''$seq_arg'''" if $seq_cmd eq 'B';
	return "\x00tt\x00$seq_arg\x00" if $seq_cmd eq 'C';
	return "\x00u\x00$seq_arg\x00" if $seq_cmd eq 'I';
	return "$seq_cmd!$seq_arg!";
}

# Copied from Pod::Html
# Takes a string e.g. =item text and returns a likely identifier (method name)
sub _p2w_fragment_id
{
    my $text     = shift;
    my $generate = shift;   # optional flag

    $text =~ s/\s+\Z//s;
    if( $text ){
        # a method or function?
        return $1 if $text =~ /(\w+)\s*\(/;
        return $1 if $text =~ /->\s*(\w+)\s*\(?/;

        # a variable name?
        return $1 if $text =~ /^([\$\@%*]\S+)/;

        # some pattern matching operator?
        return $1 if $text =~ m|^(\w+/).*/\w*$|;

        # fancy stuff... like "do { }"
        return $1 if $text =~ m|^(\w+)\s*{.*}$|;

        # honour the perlfunc manpage: func [PAR[,[ ]PAR]...]
        # and some funnies with ... Module ...
        return $1 if $text =~ m{^([a-z\d_]+)(\s+[A-Z,/& ][A-Z\d,/& ]*)?$};
        return $1 if $text =~ m{^([a-z\d]+)\s+Module(\s+[A-Z\d,/& ]+)?$};

        return _fragment_id_readable($text, $generate);
    } else {
        return;
    }
}

{
    my %seen;   # static fragment record hash

sub _flush_seen {
	%seen = ();
}

sub _fragment_id_readable {
    my $text     = shift;
    my $generate = shift;   # optional flag

    my $orig = $text;

    # leave the words for the fragment identifier,
    # change everything else to underbars.
    $text =~ s/[^A-Za-z0-9_]+/_/g; # do not use \W to avoid locale dependency.
    $text =~ s/_{2,}/_/g;
    $text =~ s/\A_//;
    $text =~ s/_\Z//;

    unless ($text)
    {
        # Nothing left after removing punctuation, so leave it as is
        # E.g. if option is named: "=item -#"

        $text = $orig;
    }

    if ($generate) {
        if ( exists $seen{$text} ) {
            # This already exists, make it unique
            $seen{$text}++;
            $text = $text . $seen{$text};
        } else {
            $seen{$text} = 1;  # first time seen this fragment
        }
    }

    $text;
}}

1;
