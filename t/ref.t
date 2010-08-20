use warnings;
use strict;

use Test::More tests => 1 + 8*12;

BEGIN { use_ok "Params::Classify", qw(is_ref ref_type); }

format foo =
.

my $foo = "";

sub test_ref_type($$) {
	my($scalar, $reftype) = @_;
	is(ref_type($scalar), $reftype);
	is(!!is_ref($scalar), !!$reftype);
	$reftype = "" if !defined($reftype);
	foreach my $type (qw(SCALAR ARRAY HASH CODE FORMAT IO)) {
		is(!!is_ref($scalar, $type), $type eq $reftype);
	}
}

test_ref_type(undef, undef);
test_ref_type("foo", undef);
test_ref_type(123, undef);
test_ref_type(*STDOUT, undef);
test_ref_type(bless({}, "main"), undef);

test_ref_type(\1, "SCALAR");
test_ref_type(\\1, "SCALAR");
test_ref_type(\pos($foo), "SCALAR");
test_ref_type([], "ARRAY");
test_ref_type({}, "HASH");
test_ref_type(\&is, "CODE");

SKIP: {
	my $format = *foo{FORMAT};
	skip "this Perl doesn't do *foo{FORMAT}", 8 unless defined $format;
	test_ref_type($format, "FORMAT");
}

1;
