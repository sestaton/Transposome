requires 'Moose', '2.0802'
requires 'MooseX::Getopt', '0.56';
requires 'MooseX::Types::Path::Class', '0.06';
requires 'namespace::autoclean', 0.13';
requires 'Try::Tiny', '0.12';
requires 'IPC::System::Simple', '1.21';
requires 'DB_File', '1.826';
requires 'Module::Path', '0.09';
requires 'Path::Class', '0.32';
requires 'YAML', '0.84';
requires 'Parallel::ForkManager', '0.7';
requires 'DBM::Deep', '0';
requires 'File::Path', '0';
requires 'Graph::UnionFind', '0';
requires 'File::Path', '0';

on 'test' => sub {
   requires 'Test::More', '>= 0.96';
};

on 'develop' sub {
   requires 'Test::Pod', '>= 1.22';
   requires 'Test::Pod::Coverage', '>= 1.08';
   requires 'Pod::Coverage '>= 0.18';
};
