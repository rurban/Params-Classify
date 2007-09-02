use Test::More tests => 45;

BEGIN { use_ok "Params::Classify", qw(is_pure_string is_pure_number); }

sub test($$$) {
	my($expect_str, $expect_num, $val) = @_;
	is !!is_pure_string($val), !!$expect_str;
	is !!is_pure_number($val), !!$expect_num;
}

test 0, 0, undef;
test 0, 0, *STDOUT;
test 0, 0, {};
test 1, 0, "";
test 1, 1, "0";
test 1, 1, "1";
test 1, 0, "1a";
test 1, 1, "-1";
test 1, 1, "123";
test 1, 0, "0123";
test 1, 0, "a";
test 1, 0, "0 but true";
test 1, 0, "00";
test 1, 1, "1.25";
test 1, 1, 1.25;
test 0, 1, 1/3;
$! = 3; test 0, 0, $!;

SKIP: {
	eval { require Scalar::Util };
	skip "dualvar() not available", 4 if $@ ne "";
	test 1, 1, Scalar::Util::dualvar(123.0, "123");
	test 0, 0, Scalar::Util::dualvar(3, "xyz");
}

SKIP: {
	skip "floating point zero is unsigned", 6
		unless sprintf("%+.f", -0.0) eq "-0";
	ok is_pure_number(0);
	ok is_pure_number(+0.0);
	ok is_pure_number(-0.0);
	SKIP: {
		eval { require Scalar::Util };
		skip "dualvar() not available", 3 if $@ ne "";
		is sprintf("%+.f", -"0") eq
			    sprintf("%+.f", -Scalar::Util::dualvar(0, "0")),
			is_pure_string(Scalar::Util::dualvar(0, "0"));
		is !!(sprintf("%+.f", -"0") eq "-0"),
			!!is_pure_string(Scalar::Util::dualvar(+0.0, "0"));
		ok !is_pure_string(Scalar::Util::dualvar(-0.0, "0"));
	}
}
