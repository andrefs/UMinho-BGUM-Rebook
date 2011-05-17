use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'UMinho::BGUM::Rebook',
    license             => 'perl',
    dist_author         => q{Andre Santos <andrefs@cpan.org>},
    dist_version_from   => 'lib/UMinho/BGUM/Rebook.pm',
    build_requires => {
        'Test::More' => 0,
        'Config::Any' => 0,
        'Moose' => 0,
    },
    add_to_cleanup      => [ 'UMinho-BGUM-Rebook-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
