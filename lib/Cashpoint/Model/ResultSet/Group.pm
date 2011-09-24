package Cashpoint::Model::ResultSet::Group;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub ordered {
    my $self = shift;
    my @groups = $self->search({}, {
        order_by => { -asc => 'groupid' }
    })->all;

    my @data = ();
    foreach my $g (@groups) {
        push @data, {
            id   => $g->group,
            name => $g->name,
            members => $g->search_related('Memberships')->count,
        };
    };

    return @data;
}

42;
