package Cashpoint::Model::ResultSet::Cashcard;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub ordered {
    my $self = shift;
    return $self->search({}, {
        order_by => { -desc => 'activationdate' },
    });
}

42;
