use 5.008008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'DR::StraMedia::SMS',
    VERSION_FROM      => 'lib/DR/StraMedia/SMS.pm', # finds $VERSION
    PREREQ_PM         => {
        'XML::LibXML'   => 0,
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/DR/StraMedia/SMS.pm', # retrieve abstract from module
    AUTHOR         => 'Dmitry E. Oboukhov <unera@debian.org>') : ()),
    LICENSE        => 'perl',
    META_MERGE => {
        resources => {
            homepage => 'https://github.com/unera/stramedia-sms',
            bugtracker => 'https://github.com/unera/stramedia-sms/issues',
        }
    },
);
