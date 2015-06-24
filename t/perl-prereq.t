#! perl
use strict;
use warnings FATAL => 'all';

use CPAN::Meta;
use Test::More;
use Test::DZil;
use Module::Metadata;

my $tzil = Builder->from_config(
	{ dist_root => 't/does_not_exist' },
	{
		add_files => {
			'source/dist.ini' => simple_ini(
				[ ModuleBuildTiny => ],
				[ Prereqs => 'RuntimeRequires' => { perl => '5.008' } ],
				[ Prereqs => 'BuildRequires' => { perl => '5.010' } ],
			),
		},
	},
);
$tzil->build;

my $VERSION = Dist::Zilla::Plugin::ModuleBuildTiny->VERSION || '<self>';
my $expected = <<"END";
# This Build.PL for DZT-Sample was generated by Dist::Zilla::Plugin::ModuleBuildTiny $VERSION.
use strict;
use warnings;

use 5.010;
use Module::Build::Tiny 0.007;
Build_PL();
END

is($tzil->built_in->file('Build.PL')->slurp, $expected, 'Build.PL declares the correct minimum perl version');

done_testing;
# vim: set ts=4 sw=4 noet nolist :
