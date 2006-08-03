use ExtUtils::MakeMaker;

WriteMakefile(
	NAME => "Params::Classify",
	VERSION_FROM => "lib/Params/Classify.pm",
	PREREQ_PM => {
		"Scalar::Util" => "1.01",
	},
);
