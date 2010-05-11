
# Enable edit locking, which will prevent users modifying records
# while other users are working on them.

$c->{locking}->{eprint}->{enable} = 1;

$c->{locking}->{eprint}->{timeout} = 3600;

