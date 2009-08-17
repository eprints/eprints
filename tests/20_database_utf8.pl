use strict;
use Test::More tests => 8;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

my $handle = EPrints::Test::get_test_session( 0 );
ok(defined $handle, 'opened an EPrints::Handle object');

my $database = $handle->get_database();
ok( defined $database, "database defined" );

SKIP: {
	skip "Only supports MySQL", 3 unless $database->isa( "EPrints::Database::mysql" );

	my $sth;

	my $utf8_string = "XXX".chr(0xe9)."XXX".chr(0x169);
	my $table = "_utf8_test_".int(rand(1000));

	$database->do("DROP TABLE IF EXISTS $table");

	eval {
		# This checks MySQL behaves as we expect it to

		### Legacy utf8-in-latin1
		# Create a latin1 table
		$database->do("SET NAMES 'latin1'");
		$database->do("CREATE TABLE $table (i CHAR(255) NOT NULL) CHARACTER SET 'latin1' COLLATE 'latin1_swedish_ci'");
		$database->do("INSERT INTO $table VALUES ('".$utf8_string."')");

		# We now have two bytes stored in a latin1 column
		$sth = $database->prepare("SELECT 1 FROM $table WHERE i like '\%e\%'");
		$sth->execute;
		# Which won't match using MySQL's collations
		ok(!defined $sth->fetch, "utf8-in-latin1");

		# We can now do the LATIN1->BINARY->UTF-8 trick
		$database->do("ALTER TABLE $table MODIFY i BINARY(255)");
		$database->do("ALTER TABLE $table MODIFY i CHAR(255) CHARACTER SET 'utf8' COLLATE 'utf8_general_ci'");

		# We now have one character stored in utf8
		$sth = $database->prepare("SELECT 1 FROM $table WHERE i like '\%e\%'");
		$sth->execute;
		# Which will match 'e' using MySQL's collations
		ok(defined $sth->fetch, "utf-8 conversion");

		$database->do("DROP TABLE IF EXISTS $table");

		$database->do("SET NAMES 'utf8'");
		$database->do("CREATE TABLE $table (i CHAR(1) NOT NULL) CHARACTER SET 'utf8' COLLATE 'utf8_general_ci'");
		$database->do("INSERT INTO $table VALUES ('".chr(0x169)."')");
		$sth = $database->prepare("SELECT * FROM $table");
		$sth->execute;
		my $c = Encode::decode_utf8($sth->fetch->[0]);
		ok($c eq chr(0x169), "CHAR(1) = 1 utf8 character");
		$database->do("DROP TABLE IF EXISTS $table");
	};

	$database->do("DROP TABLE IF EXISTS $table");
}

$handle->terminate;

ok(1);
