use Test::More tests => 4;

BEGIN { use_ok( "EPrints" ); }

my $password = "bears love picnics";

my $crypt = EPrints::Utils::crypt_password( $password );
ok($crypt =~ /^\?/, "crypt is typed");
my $uri = URI->new( $crypt );
ok(length({$uri->query_form}->{digest}), "digest is non-blank");

ok(EPrints::Utils::crypt_equals( $crypt, $password ), "password matches");
