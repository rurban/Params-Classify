use warnings;
use strict;
no strict "subs";

use Module::Build;

Module::Build->new(
	module_name => "Params::Classify",
	license => "perl",
	build_requires => {
		Module::Build => 0,
		Test::More => 0,
		perl => "5.006",
		strict => 0,
		warnings => 0,
	},
	requires => {
		Exporter => 0,
		Scalar::Util => "1.01",
		base => 0,
		perl => "5.006",
		strict => 0,
		warnings => 0,
	},
	dynamic_config => 0,
	meta_add => { distribution_type => "module" },
	create_makefile_pl => "passthrough",
	sign => 1,
)->create_build_script;

exit 0;
