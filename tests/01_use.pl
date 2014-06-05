use Test::More tests => 2;

BEGIN { use_ok( "EPrints" ); }

ok(EPrints->human_version =~ /^\d+\.\d+\.\d+$/, "version is X.Y.Z");

diag("EPrints Version: ".EPrints->human_version);
