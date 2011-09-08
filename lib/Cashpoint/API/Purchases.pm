package Cashpoint::API;

use strict;
use warnings;

use Data::Dumper;
use Dancer ':syntax';
use Dancer::Plugin::REST;
use Dancer::Plugin::DBIC;
use Scalar::Util::Numeric qw/isnum/;
use Time::Piece;

use Cashpoint::Utils;

our $VERSION = '0.1';

set serializer => 'JSON';

get qr{/products/([0-9]{13}|[0-9]{8})/purchases} => sub {
    return status_bad_request('invalid ean') unless validate_ean(my $ean = splat);
    my $product = schema('cashpoint')->resultset('Product')->search({
        ean => $ean,
    })->single;
    return status_not_found('product not found') unless $product;

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

post qr{/products/([0-9]{13}|[0-9]{8})/purchases} => sub {
    my $product = schema()->resultset('Product')->search({ean => params->{ean}})
        ->single;
    return status_not_found('product not found') unless $product;

    my @errors = ();

    my ($pdate, $edate);
    eval { $pdate = Time::Piece->strptime(params->{purchasedate} || 0, "%d-%m-%Y"); };
    $pdate += $pdate->localtime->tzoffset;
    eval { $edate = Time::Piece->strptime(params->{expirydate} || 0, "%d-%m-%Y"); };
    $edate += $edate->localtime->tzoffset;

    if (0) {
    } if (!params->{supplier} || params->{supplier} !~ /^.{5,30}$/) {
        push @errors, 'supplier must be at least 5 and up to 30 chars long';
    } if (!params->{purchasedate} || !$pdate) {
        push @errors, 'purchase date must follow dd-mm-yyyy formatting';
    } if (params->{expirydate} && !$edate) {
        push @errors, 'expiry date must follow dd-mm-yyyy formatting';
    } if (!params->{amount} || params->{amount} !~ /^\d+$/) {
        push @errors, 'amount must be greater zero';
    } if (!params->{price} || !isnum(params->{price}) || params->{price} < 0) {
        push @errors, 'price must be a positive decimal';
    }

    return status_bad_request(\@errors) if @errors;

    my $insert;
    schema->txn_do(sub {
        $insert = $product->create_related('Purchases', {
            userid       => 0, # FIXME
            supplier     => params->{supplier},
            purchasedate => $pdate->datetime,
            expirydate   => params->{expirydate} ? $edate->datetime : undef,
            amount       => params->{amount},
            price        => sprintf("%.2f", params->{price}),
        });

        # update stock
        $product->stock($product->stock+params->{amount});
        $product->update;
    });

    # xxx: check if inserted
    return status_bad_request('an error occured, please try again later') if $@;
    return status_created({id => $insert->id});
};

del qr{/products/([0-9]{13}|[0-9]{8})/purchases/([\d]+)} => sub {
    my ($ean, $id) = splat;
    my $product = schema()->resultset('Product')->search({ean => params->{ean}})
        ->single;
    return status_not_found('product not found') unless $product;

    my $purchase = schema()->resultset('Purchase')->search({purchaseid => params->{id}})
        ->single;
    return status_not_found('purchase not found') unless $purchase;

    $purchase->delete;
    return status_ok();
};

42;
