use strict;
use warnings;

use Test::More tests => 2;

use WmlTest ();

WmlTest::init();

#
#   TEST 1-2: throughput
#

my $pass = 6;

# TEST*2
WmlTest::generic( $pass, <<'EOT_IN', <<'EOT_OUT', '' );
{:[[s/�/&auml;/]][[s/�/&uuml;/]][[tr/[a-z]/[A-Z]/]]
Foo Bar Baz Quux with Umlauts � and �
:}
EOT_IN

FOO BAR BAZ QUUX WITH UMLAUTS &AUML; AND &UUML;

EOT_OUT

WmlTest::cleanup();
