package Cashpoint::BasketGuard;

use strict;
use warnings;

use Exporter 'import';
use Data::Dumper;

use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use Dancer::Plugin::REST;

our @EXPORT = qw/valid_basket/;

sub valid_basket {
    my ($sub, @args) = @_;

    return sub {
        my ($basketid) = splat;
        my $basket = schema('cashpoint')->resultset('Basket')->find($basketid);
        return status_not_found('basket not found') unless $basket;

        my $cashcard = Cashpoint::Context->get('cashcard');
        my $userid = Cashpoint::Context->get('userid');

        return status_bad_request('no cashcard available') unless $cashcard;

        if ($basket->cashcard->user != $userid) {
            return status_not_found('basket not found');
        }
        if ($basket->cashcard->id ne $cashcard) {
            return status_bad_request('invalid cashcard');
        }

        return &$sub($basket, @args);
    }
}

42;
