package Cashpoint::Model::ResultSet::Product;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub ordered {
    my $self = shift;
    return $self->search(undef, {
        order_by => { -asc => 'name' }
    });
}

42;
