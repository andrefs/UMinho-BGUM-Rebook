#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'UMinho::BGUM::Rebook' ) || print "Bail out!
";
}

diag( "Testing UMinho::BGUM::Rebook $UMinho::BGUM::Rebook::VERSION, Perl $], $^X" );
