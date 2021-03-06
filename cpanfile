requires 'Moose',                      '2.0802';
requires 'MooseX::Types::Path::Class', '0.06';
requires 'IPC::System::Simple',        '1.21';
requires 'Module::Path',               '0.09';
requires 'Path::Class',                '0.32';
requires 'YAML::Tiny',                 '1.62';
requires 'Parallel::ForkManager',      '0.7.0';
requires 'DBD::SQLite',                '1.44';
requires 'Tie::Hash::DBD',             '0.13';
requires 'Log::Log4perl',              '1.40';
requires 'DateTime',                   '1.03';
requires 'Log::Any';
requires 'Log::Any::Adapter::Log4perl';
requires 'IO::Zlib';
requires 'Archive::Tar';
requires 'Capture::Tiny';
requires 'List::MoreUtils'; 
requires 'Test::Most';
requires 'Lingua::EN::Inflect';
requires 'File::Path';
requires 'Graph';
requires 'aliased';
requires 'autodie';
#requires 'Data::Dump'; # for debugging

on 'test' => sub {
   requires 'Test::More', '0.96';
};

on 'develop' => sub {
   requires 'Test::Pod',           '1.22';
   requires 'Test::Pod::Coverage', '1.08';
   requires 'Pod::Coverage',       '0.18';
};
