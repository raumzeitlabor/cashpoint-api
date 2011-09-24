package Cashpoint::BasketGuard;

use strict;
use warnings;

use Exporter 'import';
use Data::Dumper;

use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use Dancer::Plugin::REST;
use Log::Log4perl qw( :easy );

our @EXPORT = qw/valid_basket/;

sub valid_basket {
    my ($sub, @args) = @_;

    return sub {
        my ($basketid) = splat;
        my $basket = schema('cashpoint')->resultset('Basket')->find($basketid);

        unless ($basket) {
            WARN 'could not find basket with id '.$basketid;
            return status_not_found('basket not found');
        }

        my $cashcard = Cashpoint::Context->get('cashcard');
        my $userid = Cashpoint::Context->get('userid');

        unless ($cashcard) {
            WARN 'no unlocked cashcard available, refusing request';
            return status_bad_request('no cashcard available');
        }

        if ($basket->cashcard->user != $userid) {
            WARN 'owner of basket does not match session owner';
            return status_not_found('basket not found');
        }
        if ($basket->cashcard->id ne $cashcard) {
            WARN 'owner cashcard of basket does not match session cashcard';
            return status_bad_request('invalid cashcard');
        }

        return &$sub($basket, @args);
    }
}

42;
