use Test::More tests => 71;

BEGIN {
	use_ok "Params::Classify", qw(
		scalar_class is_undef is_string
		is_number is_glob is_ref is_blessed
	);
}

sub test_scalar_classification($$$$$$$$) {
	my($scalar, $class, $iu, $is, $in, $ig, $ir, $ib) = @_;
	is(scalar_class($scalar), $class);
	is(!!is_undef($scalar), !!$iu);
	is(!!is_string($scalar), !!$is);
	is(!!is_number($scalar), !!$in);
	is(!!is_glob($scalar), !!$ig);
	is(!!is_ref($scalar), !!$ir);
	is(!!is_blessed($scalar), !!$ib);
}

test_scalar_classification(undef,             "UNDEF",   1, 0, 0, 0, 0, 0);
test_scalar_classification("",                "STRING",  0, 1, 0, 0, 0, 0);
test_scalar_classification("abc",             "STRING",  0, 1, 0, 0, 0, 0);
test_scalar_classification(123,               "STRING",  0, 1, 1, 0, 0, 0);
test_scalar_classification(0,                 "STRING",  0, 1, 1, 0, 0, 0);
test_scalar_classification("0 but true",      "STRING",  0, 1, 1, 0, 0, 0);
test_scalar_classification("1ab",             "STRING",  0, 1, 0, 0, 0, 0);
test_scalar_classification(*STDOUT,           "GLOB",    0, 0, 0, 1, 0, 0);
test_scalar_classification({},                "REF",     0, 0, 0, 0, 1, 0);
test_scalar_classification(bless({}, "main"), "BLESSED", 0, 0, 0, 0, 0, 1);

1;
