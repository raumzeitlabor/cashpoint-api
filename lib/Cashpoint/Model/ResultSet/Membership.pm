package Cashpoint::Model::ResultSet::Membership;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use BenutzerDB::User;

sub ordered {
    my ($self, $groupid) = @_;

    my $memberships = $self->search({
        groupid => $groupid,
    }, {
        order_by => { -asc => 'membershipid' },
    });

    my @data = ();
    while (my $m = $memberships->next) {
        my $user = get_user($m->id);
        push @data, {
            user => {
                id   => $user->{userid},
                name => $user->{username},
            }
        };
    }

    return @data;
}

42;
