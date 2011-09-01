package Cashpoint::Model::Price;

use strict;
use warnings;

sub new {
    my ($class, $condition, $value) = @_;
    my $self = { condition => $condition, value => $value };
    bless $self, $class;
    return $self;
}

sub condition {
    my $self = shift;
    return $self->{condition};
}

sub value {
    my $self = shift;
    return $self->{value};
}

42;
