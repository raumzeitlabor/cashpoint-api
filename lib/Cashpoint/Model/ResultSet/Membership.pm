package Cashpoint::Model::ResultSet::Membership;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub ordered {
    my ($self, $groupid) = @_;

    my $memberships = $self->search({
        groupid => $groupid,
    }, {
        order_by => { -asc => 'membershipid' },
    });

    my @data = ();
    while (my $m = $memberships->next) {
        push @data, {
            id   => $m->id,
            user => $m->user,
        };
    }

    return @data;
}

42;
