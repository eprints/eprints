
# EPM Configuration File

$c->{epm_sources} = [] if !defined $c->{epm_sources};

# Define the EPM sources
push @{$c->{epm_sources}}, {
                name => "EPrints Files",
                base_url => "http://files.eprints.org",
};
