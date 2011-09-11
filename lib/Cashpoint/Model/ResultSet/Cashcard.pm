package Cashpoint::Model::ResultSet::Cashcard;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use Cashpoint::Context;

sub ordered {
    my $self = shift;

    # only display cashcards registered to the current user
    my @params = ();
    if (Cashpoint::Context->get('role') ne 'admin') {
        @params = (userid => Cashpoint::Context->get('userid'))
    }

    return $self->search({@params}, {
        order_by => { -desc => 'activationdate' },
    });
}

42;
