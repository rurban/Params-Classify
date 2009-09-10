use warnings;
use strict;

use Test::More tests => 193;

BEGIN { use_ok "Params::Classify", qw(
	is_ref check_ref
	is_blessed check_blessed
	is_strictly_blessed check_strictly_blessed
	is_able check_able
); }

foreach my $arg (
	undef,
	"foo",
	*STDOUT,
	bless({}, "main"),
	\1,
	{},
) {
	foreach my $type (undef, *STDOUT, {}) {
		foreach my $func (\&is_ref, \&check_ref) {
			eval { $func->($arg, $type); };
			is $@, "reference type argument is not a string\n";
		}
	}
	eval { is_ref($arg, "WIBBLE"); };
	is $@, "invalid reference type\n";
	eval { check_ref($arg, "WIBBLE"); };
	is $@, "invalid reference type\n";
	foreach my $class (undef, *STDOUT, {}) {
		foreach my $func (
			\&is_blessed, \&check_blessed,
			\&is_strictly_blessed, \&check_strictly_blessed,
		) {
			eval { $func->($arg, $class); };
			is $@, "class argument is not a string\n";
		}
	}
	foreach my $meth (undef, *STDOUT, {}) {
		foreach my $func (\&is_able, \&check_able) {
			eval { $func->($arg, $meth); };
			is $@, "methods argument is not a string or array\n";
			eval { $func->($arg, [$meth]); };
			is $@, "method name is not a string\n";
		}
	}
}

1;
