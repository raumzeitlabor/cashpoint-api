package Cashpoint::Model::ResultSet::Group;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub ordered {
    my $self = shift;
    return $self->search({}, {
        order_by => { -asc => 'groupid' }
    });
}

42;
