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
				[ ModuleBuildTiny => {
						minimum_perl => $],
					}
				],
				'MetaJSON',
			),
		},
	},
);
$tzil->build;

my $VERSION = Dist::Zilla::Plugin::ModuleBuildTiny->VERSION || '<self>';
my $mbt_version = Module::Metadata->new_from_module('Module::Build::Tiny')->version;
my $expected = <<"END";
# This Build.PL for DZT-Sample was generated by Dist::Zilla::Plugin::ModuleBuildTiny $VERSION.
use strict;
use warnings;

use $];
use Module::Build::Tiny $mbt_version;
Build_PL();
END

is($tzil->built_in->file('Build.PL')->slurp, $expected, 'Build.PL is exactly like expected');

my $meta = CPAN::Meta->load_file($tzil->built_in->file('META.json'), { lazy_validation => 0 });
my $configure_requires = $meta->effective_prereqs->requirements_for('configure', 'requires')->as_string_hash;
is_deeply($configure_requires, { 'Module::Build::Tiny' => $mbt_version }, 'configure requires' );
my $build_requires = $meta->effective_prereqs->requirements_for('build', 'requires')->as_string_hash;
is_deeply($build_requires, { 'Module::Build::Tiny' => $mbt_version }, 'build requires' );

done_testing;

# vim: set ts=4 sw=4 noet nolist :
