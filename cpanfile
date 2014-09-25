requires 'Moose', '>= 2.0802';
requires 'MooseX::Getopt', '>= 0.56';
requires 'MooseX::Getopt::Usage', '>= 0.24';
requires 'MooseX::Log::Log4perl', '>= 0.46';
requires 'MooseX::Types::Path::Class', '>= 0.06';
requires 'MooseX::Types', '>= 0.38';
requires 'Method::Signatures', '>= 20131010';
requires 'namespace::autoclean', '>= 0.13';
requires 'Try::Tiny', '>= 0.12';
requires 'IPC::System::Simple', '>= 1.21';
requires 'Module::Path', '>= 0.09';
requires 'Path::Class', '>= 0.32';
requires 'YAML::Tiny', '>= 1.62';
requires 'Parallel::ForkManager', '>= 0.7.0';
requires 'DBM::Deep', '>= 2.0008';
requires 'BerkeleyDB', '>= 0.54';
requires 'Log::Log4perl', '>= 1.40';
requires 'DateTime', '>= 1.03';
requires 'Test::Most';
requires 'Lingua::EN::Inflect';
requires 'File::Path';
requires 'Graph';

on 'test' => sub {
   requires 'Test::More', '>= 0.96';
};

on 'develop' => sub {
   requires 'Test::Pod', '>= 1.22';
   requires 'Test::Pod::Coverage', '>= 1.08';
   requires 'Pod::Coverage', '>= 0.18';
};
