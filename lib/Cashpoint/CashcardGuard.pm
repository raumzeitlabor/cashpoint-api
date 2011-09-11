package Cashpoint::CashcardGuard;

use strict;
use warnings;

use Exporter 'import';
use Data::Dumper;

use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use Dancer::Plugin::REST;

our @EXPORT = qw/valid_cashcard valid_enabled_cashcard/;

sub valid_cashcard {
    my ($sub, @args) = @_;

    return sub {
        my ($code) = splat;
        my $cashcard = schema('cashpoint')->resultset('Cashcard')->find({
            code => $code,
        }) || return status_not_found("cashcard not found");;

        return &$sub($cashcard, @args);
    }
}

sub valid_enabled_cashcard {
    my ($sub, @args) = @_;

    return sub {
        my ($code) = splat;
        my $cashcard = schema('cashpoint')->resultset('Cashcard')->find({
            code     => $code,
            disabled => 1,
        }) || return status_not_found("cashcard not found");;

        return &$sub($cashcard, @args);
    }
}

42;
