package Cashpoint::Model::ResultSet::Cashcard;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use Cashpoint::Context;
use BenutzerDB::User;

sub ctx_ordered {
    my $self = shift;

    my $cashcards = $self->search({}, {
        order_by => { -desc => 'activationdate' },
        prefetch => 'groupid',
    });

    $cashcards = $self->policy($cashcards);

    # this is nice, but it does not resolve relationship the way we need
    #my @data = map { { $_->get_columns } } $self->policy($cashcards)->all;

    my @data = ();
    while (my $c = $cashcards->next) {
        my $cdata = {
            code         => $c->code,
            group        => {
                id   => $c->group->id,
                name => $c->group->name,
            },
            activated_on => $c->activationdate->datetime,
            disabled     => $c->disabled,
        };

        # add user information if admin
        $cdata->{user} = {
            id => $c->user,
            name => get_user($c->user)->{username},
        } if Cashpoint::Context->get('role') eq 'admin';

        push @data, $cdata;
    }

    return @data;
}

sub policy {
    my ($self, $rs) = @_;
    return $rs if (Cashpoint::Context->get('role') eq 'admin');
    return $rs->search({ userid => Cashpoint::Context->get('userid') });
};

42;
