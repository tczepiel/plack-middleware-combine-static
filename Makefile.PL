use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'Plack::Middleware::DynamicAssets',
    VERSION_FROM => 'lib/Plack/Middleware/DynamicAssets.pm',    # finds $VERSION
    PREREQ_PM    => {
        'Plack::Request' => 0,
        'Try::Tiny'      => 0,
        'Perl6::Slurp'   => 0,
        'Class::Load'    => 0,
    },
    (
        $] >= 5.005
        ?    ## Add these new keywords supported since 5.005
          (
            ABSTRACT_FROM => 'lib/Plack/Middleware/DynamicAssets.pm'
            ,    # retrieve abstract from module
            AUTHOR => 'tjmc <tjmc@cpan.org>'
          )
        : ()
    ),
);
