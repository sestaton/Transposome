requires 'Moose', '>= 2.0802';
requires 'MooseX::Getopt', '>= 0.56';
requires 'MooseX::Getopt::Usage', '>= 0.14';
requires 'MooseX::Getopt::Usage::Role::Man', '>= 0.14';
requires 'MooseX::Log::Log4perl', '>= 0.46';
requires 'MooseX::Types::Path::Class', '>= 0.06';
requires 'MooseX::Types::Moose', '>= 0.38';
requires 'MooseX::Method::Signatures', '>= 0.46';
requires 'namespace::autoclean', '>= 0.13';
requires 'Try::Tiny', '>= 0.12';
requires 'IPC::System::Simple', '>= 1.21';
requires 'Module::Path', '>= 0.09';
requires 'Path::Class', '>= 0.32';
requires 'YAML', '>= 0.84';
requires 'Parallel::ForkManager', '>= 0.7.0';
requires 'DBM::Deep', '>= 2.0008';
requires 'DB_File', '>= 1.826';
requires 'Log::Log4perl', '>= 1.40';
requires 'DateTime', '>= 1.03';
requires 'Lingua::EN::Inflect';
requires 'File::Path';
requires 'Graph::UnionFind';

on 'test' => sub {
   requires 'Test::More', '>= 0.96';
};

on 'develop' => sub {
   requires 'Test::Pod', '>= 1.22';
   requires 'Test::Pod::Coverage', '>= 1.08';
   requires 'Pod::Coverage', '>= 0.18';
};
