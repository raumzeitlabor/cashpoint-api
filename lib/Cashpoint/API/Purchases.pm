package Cashpoint::API;

use strict;
use warnings;

use Data::Dumper;
use Dancer ':syntax';
use Dancer::Plugin::REST;
use Dancer::Plugin::DBIC;

use Time::Piece;
use Scalar::Util::Numeric qw/isfloat/;

our $VERSION = '0.1';

set serializer => 'JSON';

get '/products/:ean/purchases' => sub {
    my $product = schema()->resultset('Product')->search({ean => params->{ean}})
        ->single;
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

post '/products/:ean/purchases' => sub {
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
    } if (!params->{price} || !isfloat(params->{price})) {
        push @errors, 'price must be a decimal';
    }

    return status_bad_request(\@errors) if @errors;

    my $insert = $product->create_related('Purchases', {
        userid       => 0, # FIXME
        supplier     => params->{supplier},
        purchasedate => $pdate->datetime,
        expirydate   => params->{expirydate} ? $edate->datetime : undef,
        amount       => params->{amount},
        price        => params->{price},
    });

    # xxx: check if inserted
    return status_created({id => $insert->id});
};

del '/products/:ean/purchases/:id' => sub {
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
