package Citation::Parser::Simple;
use utf8;
@ISA = ("Citation::Parser");

my(@templates) = 
(
	"TI: Title  _TITLE_ AU: Author  _AUTHORS_ SO: Source  _PUBLICATION_; _VOLUME_ _YEAR_, p._PAGES_ IS: ISSN  _ISSN_", 
	"_ANY_  Volume _VOLUME_: _PUBLICATION_  _YEAR_ _ANY_ ISBN _ISBN_ _ANY_  _TITLE_",
	"_TITLE_ _AULAST_, _AUFIRST_ _PUBLICATION_, _VOLUME_, _ISSUE_, _PAGES_, _ANY_ _YEAR_",
	"_TITLE_ _AUFIRST_ _AULAST_, _ANY_ _PUBLICATION_, _VOLUME_, _PAGES_, _ANY_ _YEAR_",
	"_AUTHORS_ (_YEAR_). _TITLE_. _PUBLICATION_ _VOLUME_(_ISSUE_) _PAGES_",
	"_AUTHORS_. _TITLE_. _PUBLICATION_. _YEAR_;_VOLUME_:_PAGES_",
	"_AUTHORS_ (_YEAR_) _TITLE_. _PUBLICATION_ _VOLUME_:_PAGES_.?",
	"_AUTHORS_ (_YEAR_) _TITLE_. _PUBLICATION_ _VOLUME_:_PAGES_.",
	"_AUTHORS_ (_YEAR_). _TITLE_. _PUBLICATION_, _VOLUME_, _SPAGE_-- _EPAGE_.",
	"_AUTHORS_ (_YEAR_) _TITLE_. _PUBLICATION_ _VOLUME_(_ISSUE_):_PAGES_.",
	"_ANY_ _AUFIRST_ _AULAST_ Pages _PAGES_ of: _PUBLICATION_, _ANY_ _YEAR_",
	"_AUTHORS_. _TITLE_. _PUBLICATION_, _VOLUME_:_PAGES_, _YEAR_.",
	"_AUTHORS_ (_YEAR_). _TITLE_, _PUBLICATION_, _VOLUME_(_ISSUE_):_PAGES_",
	"_AUTHORS_. _TITLE_ _UCPUBLICATION_ _VOLUME_ (_ISSUE_): _PAGES_ _ANY_ _YEAR_",
	"_AUTHORS_. _TITLE_. _PUBLICATION_. _YEAR_ _ANY_;_VOLUME_(_ISSUE_):_PAGES_.",
	"_AUTHORS_. _TITLE_. _PUBLICATION_ _YEAR_;_VOLUME_(_ISSUE_):_PAGES_",
	"_AUTHORS_. _TITLE_. _PUBLICATION_._YEAR_ _ANY_;_VOLUME_(_ISSUE_):_PAGES_.",
	"_AUTHORS_. _TITLE_. _PUBLICATION_, v. _VOLUME_, n_ISSUE_: _PAGES_. ISSN _ISSN_",
	"_AUTHORS_ _CAPTITLE_ _CAPPUBLICATION_ _ANY_, _YEAR_ Volume _VOLUME_, no. _ISSUE_",
	"_TITLE_; _ANY_ _YEAR_; _AUTHORS_; Issue: _ISSUE_ Start Page: _SPAGE_ ISSN: _ISSN__ANY_",
	"_AUTHORS_, _TITLE_; _ANY_ _YEAR_; Issue:  _ISSUE_ Start Page: _SPAGE_ ISSN:  _ISSN__ANY_",
	"_AUTHORS_ (_YEAR_). _TITLE_. In _ANY_, _CAPPUBLICATION_ _ANY_: _ANY_.",
	"_AUTHORS_ in _PUBLICATION_ _YEAR_. _TITLE_. _PAGES_",
	"_AUTHORS_. (_YEAR_) \"_TITLE_\". _PUBLICATION_, _ANY_ _PAGES_",
	"_AUTHORS_; _PUBLICATION_ [_ANY_] _YEAR_, _VOLUME_(_ISSUE_), _PAGES_.",
	"_AUTHORS_ (_YEAR_) _TITLE_. _PUBLICATION_ _VOLUME_: _PAGES_",
	"_AUTHORS_ (_YEAR_) _TITLE_ _PUBLICATION_ _ANY_ _VOLUME_: _PAGES_",
	"_AUTHORS_ (_YEAR_) _TITLE_. _PUBLICATION_ _VOLUME_(_ISSUE_) _PAGES_.",
	"_AUTHORS_ (_YEAR_) _TITLE_. _PUBLICATION_ _VOLUME_(_ISSUE_) _PAGES_",
	"_AUTHORS_ (_YEAR_) _TITLE_. _PUBLICATION_ B_VOLUME_:_PAGES_",
	"_AUTHORS_ (_YEAR_)_TITLE_. _PUBLICATION_ B_VOLUME_:_PAGES_",
	"_AUTHORS_ (_YEAR_) _TITLE_. _PUBLICATION_ _VOLUME_(_ISSUE_).",
	"_AUTHORS_ (_YEAR_). _TITLE_. _PUBLICATION_, _VOLUME_, _PAGES_.",
	"_AUTHORS_ (_YEAR_).? _TITLE_. _PUBLICATION_ _VOLUME_(_ISSUE_):_PAGES_.",
	"_AUTHORS_. (_YEAR_). _TITLE_. _PUBLICATION_ _VOLUME_(_ISSUE_) pp._PAGES_.",
	"_AUTHORS_ (_YEAR_). _TITLE_. _PUBLICATION_, _VOLUME_ (_ISSUE_, _ANY_).",
	"_AUTHORS_. (_YEAR_). _TITLE_. _PUBLICATION_ _VOLUME_ (_ANY_).",
	"_AUTHORS_. (_YEAR_). _TITLE_. _ANY_ _VOLUME_(_ISSUE__ANY_) pp._PAGES_.",
	"_AUTHORS_. _YEAR_. _TITLE_. _PUBLICATION_: _ANY_. _VOLUME_(_ISSUE_): _PAGES_",
	"_AUTHORS_ _PUBLICATION_ _YEAR_, _PAGES_",
	"_AUTHORS_;_PUBLICATION_ _YEAR_, _VOLUME_(_ISSUE_), _ANY_",
	"_AUTHORS_ _TITLE_, _PUBLICATION_ _VOLUME_ (_YEAR_) pp. _PAGES_",
	"_AUTHORS_ _TITLE_. _PUBLICATION_. _YEAR_; _VOLUME_(_ISSUE_):_SPAGE_",
	"_AUTHORS_, _TITLE_, _PUBLICATION_, _VOLUME_ (_YEAR_) p_PAGES_",
	"_AUTHORS_  _PUBLICATION_ (_YEAR_) p_PAGES_",
	"_AUTHORS_ _TITLE_. _PUBLICATION_. _VOLUME_ (_YEAR_) pp. _PAGES_.",
	"_PUBLICATION_ V._VOLUME_ #_ISSUE_ _YEAR_ p._PAGES_ _TITLE_ Au: _AUTHORS_",
	"_AUTHORS_. _TITLE_. _PUBLICATION_ _VOLUME_:_PAGES_. _YEAR_.",
	"_AUTHORS_ _PUBLICATION_ [_ANY_] _YEAR_, _VOLUME_ (_ISSUE_), _PAGES_.",
	"_AUTHORS_. _TITLE_. _PUBLICATION_. _ANY_ _YEAR_. _VOLUME_.",
	"_AUTHORS_ (_YEAR_) _PUBLICATION_ _VOLUME_ _YEAR_-_ANY_",
	"_AUTHORS_. _TITLE_. _PUBLICATION_ _VOLUME_, _YEAR_.",
	"_AUTHORS_. _TITLE_. _PUBLICATION_. _ANY_. _ANY_, _YEAR_",
	"_AUTHORS_ (_YEAR_). \"_TITLE_\" _PUBLICATION_ _VOLUME_.",
	"_AUTHORS_. _TITLE_. _PUBLICATION_ _YEAR_. _ANY_",
	"_AUTHORS_. _TITLE_. _PUBLICATION_, _YEAR_.",
	"_AUTHORS_ (_YEAR_) _TITLE_. _ANY_:_PUBLICATION_.",
	"_AUTHORS_ (_YEAR_) _TITLE_. _PUBLICATION_ (_ANY_.",
	"_AUTHORS_: \"_TITLE_\" _PUBLICATION_",
	"_TITLE_ Pages _PAGES_ _AUTHORS_",
	"_PUBLICATION_, _ANY_ _YEAR_ v_VOLUME_ i_ISSUE_ p_SPAGE_(_ANY_) _TITLE_ (_ANY_) _AUTHORS__ANY_",
	"_TITLE_  _AUTHORS_  _PUBLICATION_, v _VOLUME_, n _ISSUE_, (_ANY_ _YEAR_), p _PAGES_",
	"_TITLE_; _AUTHORS_; _PUBLICATION_, _ANY_; _ANY_ _YEAR_; Vol. _VOLUME_, Iss. _ISSUE_; pg. _SPAGE_",
	"_TITLE_; _AUTHORS_; _PUBLICATION_; _ANY_, _YEAR_; Vol. _VOLUME_, Iss. _ISSUE_; pg. _SPAGE_",
	"_TITLE_; By: _AUTHORS_, _PUBLICATION, _DATE_, Vol. _VOLUME_ Issue _ISSUE_, p_SPAGE_, _ANY_",
	"_TITLE_, _AUTHORS_, _PUBLICATION_ _VOLUME_, _ISSUE__ANY_ _PAGES_ (_YEAR_)",
	"_AUTHORS_ (_YEAR_). _TITLE_? _PUBLICATION_, _VOLUME_(_ISSUE_), _PAGES_.",
	"_AUTHORS_ (_YEAR_). _TITLE_. _PUBLICATION_, _VOLUME_(_ISSUE_), _PAGES_",
	"_PUBLICATION_ Vol _VOLUME_(_ISSUE_), _ANY_ _YEAR_, _PAGES_",
	"_AUTHORS_; _PUBLICATION_, v_VOLUME_ n_ISSUE_ p_PAGES_ _ANY_ _YEAR_",
	"_AUTHORS_ (_YEAR_). _TITLE_. _PUBLICATION_, _VOLUME_(_ISSUE_), _PAGES_.",
	"_AUTHORS_ (_YEAR_). _TITLE_._ANY_ (_ANY_pp. _PAGES_). _ANY_",
	"_PUBLICATION_, v_VOLUME_ n_ISSUE_ p_SPAGE_ _ANY_ _YEAR_",
	"_AUTHORS_ _ANY_(_YEAR_). _TITLE_. _ANY_.",
	"_AUTHORS_ (_YEAR_) _TITLE_. _PUBLICATION_, _VOLUME_, _PAGES_.",
	"_AUTHORS_(_YEAR_). _TITLE_. _ANY_.",
	"_AUTHORS_. _TITLE_. _PUBLICATION_. _YEAR_",
	"_TITLE_; _ANY_ _YEAR_; _AUTHORS_",
	"_TITLE_ by _AUTHORS_ _ANY_",
	"_AUTHORS_ (_YEAR_). _TITLE_. In _ANY_",
	"_AUTHORS_ (_YEAR_). _TITLE_._ANY_",
	"_AUTHORS_ (_YEAR_) _TITLE_. _PUBLICATION_.",
	"_AUTHORS_ (_YEAR_) _TITLE_",
	"_PUBLICATION_ volume _VOLUME_ page _SPAGE_",
	"_AUTHORS_, \"_TITLE_\", _PUBLICATION_ _VOLUME_ (_YEAR_) pp. _PAGES__ANY_",
	"_TITLE_. _AUTHORS_. _PUBLICATION_,_ANY_ _YEAR_",
	"_PUBLICATION_ (_YEAR_).  _TITLE_. _ANY_",
	"_PUBLICATION_ _VOLUME_: _PAGES_.",
	"_AUTHORS_. _TITLE_. _PUBLICATION_ _VOLUME_: _PAGES_. _YEAR_.",
	"_TITLE_, _AUTHORS_. _PUBLICATION_, _ANY_ _YEAR_.",
	"_TITLE_, _PUBLICATION_, _ANY_ _YEAR_.",
	"_AUTHORS_, _TITLE_, _PUBLICATION_, _ANY_, _YEAR__ANY_",
	"_PUBLICATION_ _YEAR_ _TITLE_",
	"_PUBLICATION_  _AUTHORS_  _TITLE_",
	"_AUTHORS_. _TITLE_",
	"_AUTHORS_, _TITLE_",
	"_AUTHORS_  _TITLE_",
	"_TITLE_",
);

sub new
{
	my($class) = @_;
	my $self = {};
	return bless($self, $class);
}

sub strip_spaces
{	
	my(@bits) = @_;
	foreach(@bits) { s/^\s*(.+)\s*$/$1/; }
	return @bits;
}

sub get_templates
{
	return @templates;
}

sub handle_authors
{
	my($authstr) = @_;
	my @authsout = ();
	$authstr =~ s/\bet al\b//;
	# Handle semicolon lists
	if ($authstr =~ /;/)
	{
		my @auths = split /\s*;\s*/, $authstr;
		foreach(@auths)
		{
			my @bits = split /[,\s]+/;
			@bits = strip_spaces(@bits);
			push @authsout, {family => $bits[0], given => $bits[1]};
		}
	}
	elsif ($authstr =~ /^[[:upper:]\.]+\s+[[:alnum:]]/)
	{
		my @bits = split /\s+/, $authstr;
		@bits = strip_spaces(@bits);
		my $fam = 0;
		my($family, $given);
		foreach(@bits)
		{
			next if ($_ eq "and" || $_ eq "&" || /^\s*$/);
			s/,//g;
			if ($fam)
			{
				$family = $_;
				push @authsout, {family => $family, given => $given};
				$fam = 0;
			}
			else
			{
				$given = $_;
				$fam = 1;
			}
		}
	}
	elsif ($authstr =~ /^.+\s+[[:upper:]\.]+/)
	{
		# Foo AJ, Bar PJ
		my $fam = 1;
		my $family = "";
		my $given = "";
		my @bits = split /\s+/, $authstr;
		@bits = strip_spaces(@bits);
		foreach(@bits)
		{
			s/[,;\.]//g;
			s/\bet al\b//g;
			s/\band\b//;
			s/\b&\b//;
			next if /^\s*$/;
			if ($fam == 1)
			{
				$family = $_;
				$fam = 0;
			}
			else
			{
				$given = $_;
				$fam = 1;
				push @authsout, {family => $family, given => $given};
				
			}
		}

	} 
	elsif ($authstr =~ /^.+,\s*.+/ || $authstr =~ /.+\band\b.+/)
	{
		my $fam = 1;
		my $family = "";
		my $given = "";
		my @bits = split /\s*,|\band\b|&\s*/, $authstr;
		@bits = strip_spaces(@bits);
		foreach(@bits)
		{
			next if /^\s*$/;
			if ($fam)
			{
				$family = $_;
				$fam = 0;	
			}
			else
			{
				$given = $_;
				push @authsout, {family => $family, given => $given};
				$fam = 1;
			}
		}
	}
	elsif ($authstr =~ /^[[:alpha:]\s]+$/)
	{
		$authstr =~ /^([[:alpha:]]+)\s*([[:alpha:]]*)$/;
		my $given = "";
		my $family = "";
		if (defined $1 && defined $2)
		{
			$given = $1;
			$family = $2;
		}
		if (!defined $2 || $2 eq "")
		{
			$family = $1;
			$given = "";
		}
		push @authsout, {family => $family, given => $given};
	}
	elsif( $authstr =~ /\w+\s+\w?\s*\w+/)
	{
		my @bits = split /\s+/, $authstr;
		my $rest = $authstr;
		$rest =~ s/$bits[-1]//;
		push @authsout, {family => $bits[-1], given => $rest};
	}
	else
	{
		
	}
	return @authsout;
}

sub score
{
	my(%metain) = @_;
	my %score =
	(
		"Y" => 0,
		"A" => 0.2,
		"AY" => 0.92,
		"T" => 0.976,
		"AT" => 0.984,
		"P" => 0.984,
		"PY" => 0.984,
		"AP" => 0.984,
		"APY" => 0.984,
		"TY" => 0.992,
		"ATY" => 0.992,
		"PT" => 0.992,
		"PTY" => 0.992,
		"APT" => 0.992,
		"APTY" => 0.992,
	);
	my @components = ();
	push @components, "Y" if (defined $metain{year} && $metain{year} ne "");
	push @components, "T" if (defined $metain{title} && $metain{title} ne "");
	push @components, "A" if (defined $metain{authors});
	push @components, "P" if (defined $metain{publication});
	@components = sort @components;
	my $compstr = join "", @components;
	return $score{$compstr};
}

sub extract_metadata
{
	my($self, $ref) = @_;
	$ref =~ s/^[^[:alpha:]]+//;
	$ref =~ s/\s+$//;
	$ref =~ s/\s{2}\s+/ /g;
	my %metaout = ();
	$metaout{ref} = $ref;

	# Pull out URLs
        $ref =~ s/(((http(s?):\/\/(www\.)?)|(\bwww\.)|(ftp:\/\/(ftp\.)?))([-\w\.:\/\S]+))(\b)//;
        $metaout{url} = $1;	
	$metaout{url} = "" if (!defined $metaout{url});

	$metaout{id} = [];
        #http://dx.doi.org/10.1000/123
        # Pull out doi addresses
	if ($ref =~ s/doi:(.+)\b//)
	{
		push @{$metaout{id}}, "doi:$1";
	}	

	my %matches =
	(
		"_AUFIRST_"	=> "([[:alpha:]\.]+)",
		"_AULAST_"	=> "([[:alpha:]-]+)",
		"_ISSN_"	=> "([\\d-]+)",
		"_AUTHORS_"	=> "([[:alpha:]\\.,;\\s&-]+)",
		"_DATE_"	=> "(\\d{2}/\\d{2}/\\d{2})",
		"_YEAR_" 	=> "(\\d{4})",
		"_TITLE_" 	=> "(.+)",
		"_UCTITLE_" 	=> "([^[:lower:]]+)",
		"_CAPTITLE_"	=> "([[:upper:]][^[:upper:]]+)",
		"_PUBLICATION_" => "(.+)",
		"_UCPUBLICATION_" => "([^[:lower:]]+)",
		"_CAPPUBLICATION_"	=> "([[:upper:]][^[:upper:]]+)",
		"_VOLUME_" 	=> "(\\d+)",
		"_ISSUE_" 	=> "(\\d+)",
		"_PAGES_" 	=> "(\\d+-\\d+?)",
		"_ANY_" 	=> "(.+?)",
		"_ISBN_"	=> "([0-9X-]+)",		
		"_SPAGE_"	=> "([0-9]+)",
		"_EPAGE_"	=> "([0-9]+)"
	);


	my(@newtemplates) = ();
	foreach my $template (@templates)
	{
		$_ = $template;
		s/\\/\\\\/g;
		s/\(/\\\(/g;
		s/\)/\\\)/g;
		s/\[/\\\[/g;
		s/\]/\\\]/g;
		s/\./\\\./g;
		s/ /\\s+/g;
		s/\?/\\\?/g;
		foreach my $key (keys %matches)
		{
			s/$key/$matches{$key}/g;
		}
		push @newtemplates,$_;
	}
	my $index = 0;	
	my @vars = ();
	my @matchedvars = ();
	foreach my $currtemplate (@newtemplates)
	{
		my $original = $templates[$index];
		$metaout{match} = $original;
		if ($ref =~ /^$currtemplate$/)
		{
			@vars = ($original =~ /_([A-Z]+)_/g);
			@matchedvars = ($ref =~ /^$currtemplate$/);
			last;
		}
		$index++;
	}
	$index = 0;
	if (scalar @matchedvars > 0)
	{
		foreach(@vars)
		{
			$matchedvars[$index] =~ s/^\s*(.+)\s*$/$1/;
			$metaout{lc $_} = $matchedvars[$index];
			$index++;
		}
	}
	foreach(keys %metaout)
	{
		if (/^uc/)
		{
			my $alt = $_;
			$alt =~ s/^uc//;
			if (!defined $metaout{$alt} || $metaout{$alt} eq "")
			{
				$metaout{$alt} = $metaout{$_};
			}
		}
	}

	# Map to OpenURL
	if (defined $metaout{authors})
	{
		$metaout{authors} = [handle_authors($metaout{authors})];
#	}	

		$metaout{aulast} = $metaout{authors}[0]->{family};
		$metaout{aufirst} = $metaout{authors}[0]->{given};
	}
	$metaout{atitle} = $metaout{title};	
	$metaout{title} = $metaout{publication};
	if (defined $metaout{cappublication}) { $metaout{title} = $metaout{cappublication} };
	$metaout{score} = score(%metaout);
	$metaout{date} = $metaout{year};
	return %metaout;

}

sub parse
{
	my($self, $ref) = @_;
	$hashout = {$self->extract_metadata($ref)};
	return $hashout;
}

1;
