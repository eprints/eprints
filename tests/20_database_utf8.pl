use strict;
use Test::More tests => 10;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

my $session = EPrints::Test::get_test_session( 0 );
ok(defined $session, 'opened an EPrints::Session object');

my $database = $session->get_database();
ok( defined $database, "database defined" );

my $dataset = $session->dataset( "eprint" );

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

{
my $utf8_byte = "\x{024b62}";
# mysql only supports 1-3 byte UTF-8
$utf8_byte = "\x{20ac}" if $database->isa( "EPrints::Database::mysql" );

# watch-out: side-effecting database!
my $eprintid = $database->counter_next( "eprintid" );

my $field = $dataset->field( "eprint_status" );
my $maxlength = $field->get_property( "maxlength" );
my $testdata = $utf8_byte x $maxlength;
my $table = $dataset->get_sql_table_name;

ok($database->insert($table,[$dataset->key_field->get_sql_name,$field->get_sql_name],[$eprintid,$testdata]), "insert maximum size multi-byte characters");

my $sth = $database->prepare("SELECT ".$database->quote_identifier($field->get_sql_name)." FROM ".$database->quote_identifier($table)." WHERE ".$database->quote_identifier($dataset->key_field->get_sql_name)."=$eprintid");
$sth->execute;
my( $stored ) = $sth->fetchrow_array;
utf8::decode($stored) if !utf8::is_utf8($stored);

is($stored,$testdata,"stored maximum size multi-byte characters");

$database->delete_from($table,[$dataset->key_field->get_sql_name],[$eprintid]);
}

$session->terminate;

ok(1);
