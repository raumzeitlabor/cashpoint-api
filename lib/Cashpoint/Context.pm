package Cashpoint::Context;

use strict;
use warnings;

use Data::Dumper;

my $self;

sub instance {
    unless (defined $self) {
        my $type = shift;
        my $this = { data => {}, };
        $self = bless $this, $type;
    }
    return $self;
}

sub reset {
    $self->{data} = {};
}

sub get {
    my (undef, $key) = @_;
    #print Dumper $self->{data};
    return $self->{data}->{$key};
}

sub set {
    my (undef, @data) = @_;
    warn 'odd number of elements' unless @data == 2;
    $self->{data}->{$data[0]} = $data[1];
}

Cashpoint::Context->instance;
