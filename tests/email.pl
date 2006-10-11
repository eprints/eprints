#!/usr/bin/perl -w  

use Test::More tests => 9;

use TestLib;
use EPrints;
use Test::MockObject;
use strict;




#
my $mock_repository;
$mock_repository = Test::MockObject->new();
$mock_repository->set_always( 'get_conf', sub { return 1; } );

ok( EPrints::Utils::send_mail( $mock_repository, 'en','Bob Smith','cjg@ecs.soton.ac.uk','test',undef,undef),
 	"sending mail returned true on success" );


$mock_repository = Test::MockObject->new();
$mock_repository->set_true( 'log' );
$mock_repository->set_always( 'get_conf', sub { return 0; } );
ok( !EPrints::Utils::send_mail( $mock_repository, 'en','Bob Smith','cjg@ecs.soton.ac.uk','test subject',undef,undef),
 	"sending mail returned false on failure" );
my @args = $mock_repository->call_args( 2 );
$mock_repository->called_ok( 'log' );
is( $args[0], $mock_repository, "log to correct repository" );
ok( index($args[1],'Failed to send mail')!=-1, 'Failure causes warning to be logged' );
ok( index($args[1],'Bob Smith')!=-1, 'Warning mentions name' );
ok( index($args[1],'cjg@ecs.soton.ac.uk')!=-1, 'Warning mentions email' );
ok( index($args[1],'test subject')!=-1, 'Warning mentions subject' );

my $date = EPrints::Utils::email_date();
ok( $date =~ m/(Mon|Tue|Wed|Thu|Fri|Sat|Sun), \d\d? (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) \d\d\d\d \d\d:\d\d:\d\d [+-]\d\d\d\d/ , 'email_date()' );

