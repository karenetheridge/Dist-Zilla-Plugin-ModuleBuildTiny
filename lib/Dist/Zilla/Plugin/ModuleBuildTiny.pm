package Dist::Zilla::Plugin::ModuleBuildTiny;

use Moose;
with qw/
	Dist::Zilla::Role::BuildPL
	Dist::Zilla::Role::TextTemplate
	Dist::Zilla::Role::PrereqSource
	Dist::Zilla::Role::FileGatherer
/;

use Module::Metadata;
use Moose::Util::TypeConstraints 'enum';
use MooseX::Types::Perl qw/StrictVersionStr/;
use List::Util qw/first/;
use Path::Iterator::Rule;

has version_method => (
	is      => 'ro',
	isa     => enum(['installed', 'conservative']),
	default => 'installed',
);

has version => (
	is      => 'ro',
	lazy    => 1,
	isa     => StrictVersionStr,
	default => sub {
		my $self = shift;
		if ($self->version_method eq 'installed') {
			return Module::Metadata->new_from_module('Module::Build::Tiny')->version->stringify;
		}
		elsif (Path::Iterator::Rule->new->file->name('*.PL')->all('lib')) {
			return '0.039';
		}
		elsif (Path::Iterator::Rule->new->file->name('*.xs')->all('lib')) {
			return '0.036';
		}
		elsif (not $self->zilla->name =~ tr/-//) {
			return '0.019';
		}
		elsif (-d 'share') {
			return '0.014';
		}
		return '0.007';
	},
);

has minimum_perl => (
	is      => 'ro',
	isa     => StrictVersionStr,
	lazy    => 1,
	default => sub {
		my $self = shift;
		my $prereqs = $self->zilla->prereqs->cpan_meta_prereqs;
		my $reqs = $prereqs->merged_requirements([ qw/configure build test runtime/ ], ['requires']);
		return $reqs->requirements_for_module('perl') || '5.006';
	},
);

my $template = <<'BUILD_PL';
# This Build.PL for {{ $dist_name }} was generated by {{ $plugin_title }}.
use strict;
use warnings;

use {{ $minimum_perl }};
use Module::Build::Tiny{{ $version ne 0 && " $version" }};
Build_PL();
BUILD_PL

sub register_prereqs {
	my ($self) = @_;

	$self->zilla->register_prereqs({ phase => 'configure' }, 'Module::Build::Tiny' => $self->version);

	return;
}

sub gather_files {
	my ($self) = @_;

	if (my $file = first { $_->name eq 'Build.PL' } @{$self->zilla->files})
	{
		# if it's another type, some other plugin added it, so it's better to
		# error out and let the developer sort out what went wrong.
		if ($file->isa('Dist::Zilla::File::OnDisk'))
		{
			$self->log('replacing existing Build.PL found in repository');
			$self->zilla->prune_file($file);
		}
	}

	require Dist::Zilla::File::InMemory;
	my $file = Dist::Zilla::File::InMemory->new({
		name => 'Build.PL',
		content => $template,	# template evaluated later
	});

	$self->add_file($file);
	return;
}

sub setup_installer {
	my ($self, $arg) = @_;

	confess "Module::Build::Tiny is currently incompatible with dynamic_config" if $self->zilla->distmeta->{dynamic_config};

	for my $map (map { $_->share_dir_map } @{$self->zilla->plugins_with(-ShareDir)}) {
		$self->log_fatal('Unsupported use of a module sharedir') if exists $map->{module};
		$self->log_fatal('Sharedir location must be share/') if defined $map->{dist} and $map->{dist} ne 'share';
	}

	my $file = first { $_->name eq 'Build.PL' } @{$self->zilla->files};
	my $content = $file->content;

	$content = $self->fill_in_string($content, {
			version      => $self->version,
			minimum_perl => $self->minimum_perl,
			dist_name    => $self->zilla->name,
			plugin_title => ref($self) . ' ' . ($self->VERSION || '<self>'),
		});

	$self->log_debug([ 'updating contents of Build.PL in memory' ]);
	$file->content($content);

	return;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

# ABSTRACT: Build a Build.PL that uses Module::Build::Tiny

=head1 DESCRIPTION

This plugin will create a F<Build.PL> for installing the dist using L<Module::Build::Tiny>.

=attr version

B<Optional:> Specify the minimum version of L<Module::Build::Tiny> to depend on.

Defaults to the version determined by C<version_method>.

=attr version_method

This attribute determines how the default minimum perl is detected. It has two possible values:

=over 4

=item * installed

This will give the version installed on the author's perl installation.

=item * conservative

This will return a heuristically determined minimum version of MBT.

=back

=attr minimum_perl

B<Optional:> Specify the minimum version of perl to require in the F<Build.PL>.

This is normally taken from dzil's prereq metadata.

=cut

# vim: set ts=4 sw=4 noet nolist :
