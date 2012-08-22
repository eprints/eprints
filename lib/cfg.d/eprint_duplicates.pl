$c->add_dataset_trigger( "eprint", EP_TRIGGER_DUPLICATE_SEARCH, sub {
    my %params = @_;

    my $dataset = $params{dataset};
    my $dataobj = $params{dataobj};
    my $ids = $params{ids};

    if( $dataobj->exists_and_set( "source" ) )
    {
        my $list = $dataset->search(filters => [
                { meta_fields => [qw( source )], value => $dataobj->value( "source" ), match=>"EX", },
                { meta_fields => [qw( metadata_visibility )], value => "show", },
            ],
            satisfy_all => 1,
            limit => 10,
        );
        $list->map(sub {
            (undef, undef, my $dupe) = @_;

            if( !defined $dataobj->id || $dataobj->id ne $dupe->id )
            {
                push @$ids, $dupe->id;
            }
        });
    }

    return EP_TRIGGER_OK;
});
