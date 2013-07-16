package Transposome::Role::Config;

use Moose::Role;
use Moose::Util::TypeConstraints;

has config => (
                isa      => ‘HashRef’,
                required => 1,
                default  => sub {
	                  _parse_config_file(“client.ini”),
                 },
              );

sub parse_config_file {
    my $self = shift;
    my $file = shift;
    
    ;
