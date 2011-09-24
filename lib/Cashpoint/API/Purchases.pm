package Cashpoint::API;

use strict;
use warnings;

use Data::Dumper;
use Dancer ':syntax';
use Dancer::Plugin::REST;
use Dancer::Plugin::DBIC;
use Scalar::Util::Numeric qw/isnum/;
use Time::Piece;
use Log::Log4perl qw( :easy );

use Cashpoint::Utils;
use Cashpoint::AccessGuard;
use Cashpoint::ProductGuard;

get qr{/products/([0-9]{13}|[0-9]{8})/purchases} => protected 'admin', valid_product sub {
    my $product = shift;
    my $purchases = $product->search_related('Purchases', {}, {
        order_by => { -desc => 'purchaseid' }
    });

    my @data = ();
    while (my $p = $purchases->next) {
        push @data, {
            supplier     => $p->supplier,
            purchasedate => $p->purchasedate->dmy,
            expirydate   => $p->expirydate ? $p->expirydate->dmy : undef,
            amount       => $p->amount,
            price        => $p->price,
        };
    }

    return status_ok(\@data);
};

post qr{/products/([0-9]{13}|[0-9]{8})/purchases} => protected 'admin', valid_product sub {
    my $product = shift;

    my ($supplier, $purchasedate, $expirydate, $amount, $price) =
        map { s/^\s+|\s+$//g if $_; $_ } (
            params->{supplier},
            params->{purchasedate},
            params->{expirydate},
            params->{amount},
            params->{price}
        );

    my ($pdate, $edate);
    eval { $pdate = Time::Piece->strptime($purchasedate || 0, "%d-%m-%Y"); };
    $pdate += $pdate->localtime->tzoffset;
    eval { $edate = Time::Piece->strptime($expirydate || 0, "%d-%m-%Y"); };
    $edate += $edate->localtime->tzoffset;

    my @errors = ();
    if (defined $supplier && (length $supplier == 0 || length $supplier > 50)) {
        push @errors, 'invalid supplier';
    }
    if (!defined $purchasedate || !$pdate) {
        push @errors, 'invalid purchase date';
    }
    if (defined $expirydate && !$edate) {
        push @errors, 'invalid expiry date';
    }
    if (!defined $amount || !isnum($amount) || $amount <= 0) {
        push @errors, 'invalid amount';
    }
    if (!defined $price || !isnum($price) || $price < 0 || (isfloat($price)
            && sprintf("%.2f", $price) ne $price)) {
        push @errors, 'invalid price';
    }

    return status_bad_request(\@errors) if @errors;

    my $insert;
    schema->txn_do(sub {
        $insert = $product->create_related('Purchases', {
            userid       => Cashpoint::Context->get('userid'),
            supplier     => $supplier,
            purchasedate => $pdate->datetime,
            expirydate   => $expirydate ? $edate->datetime : undef,
            amount       => $amount,
            price        => sprintf("%.2f", $price),
        });

        # update stock
        $product->stock($product->stock + $amount);
        $product->update;
    });

    if ($@) {
        ERROR 'could not add purchase for product '.$product->name.' ('
            .$product->id.'): '.$@;
        return status(500);
    }

    INFO 'user '.Cashpoint::Context->get('userid').' added new purchase for'
        .' product '.$product->name.' ('.$product->id.')';

    return status_created({id => $insert->id});
};

del qr{/products/([0-9]{13}|[0-9]{8})/purchases/([\d]+)} => protected 'admin', valid_product sub {
    my $product = shift;
    my ($purchaseid) = splat;

    my $purchase = $product->find_related('Purchases', $purchaseid);
    status_not_found('purchase not found') unless $purchase;

    $purchase->delete;

    INFO 'user '.Cashpoint::Context->get('userid').' deleted purchase '
        .$purchaseid.' of product '.$product->name.' ('.$product->id.')';

    return status_ok();
};

42;
