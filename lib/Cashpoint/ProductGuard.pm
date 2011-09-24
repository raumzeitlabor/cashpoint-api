package Cashpoint::ProductGuard;

use strict;
use warnings;

use Exporter 'import';
use Data::Dumper;
use Dancer ':syntax';
use Dancer::Plugin::REST;
use Dancer::Plugin::DBIC;
use Algorithm::CheckDigits;

our @EXPORT = qw/valid_product/;

sub valid_product {
    my ($sub, @args) = @_;

    return sub {
        return status_bad_request('invalid ean') unless validate_ean(my $ean = splat);
        my $product = schema('cashpoint')->resultset('Product')->find({
            ean => $ean,
        }) || return status_not_found('product not found');

        return &$sub($product, @args);
    }
};
