package Cashpoint::Model::ResultSet::Group;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub ordered {
    my $self = shift;
    my $groups = $self->search({}, {
        order_by => { -asc => 'groupid' }
    });

    my @data = ();
    while (my $g = $groups->next) {
        push @data, {
            group => $g->group,
            name  => $g->name,
        };
    };

    return @data;
}

42;
