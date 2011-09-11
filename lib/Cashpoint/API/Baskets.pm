package Cashpoint::API;

use strict;
use warnings;

use Data::Dumper;
use Dancer ':syntax';
use Dancer::Plugin::REST;
use Dancer::Plugin::DBIC;

use DateTime;
use Algorithm::CheckDigits;
use Cashpoint::AccessGuard;
use Cashpoint::BasketGuard;

our $VERSION = '0.1';

post '/baskets' => protected sub {
    # make sure /baskets is not accessed from external
    return status(403) unless request->address eq '127.0.0.1';

    unless (Cashpoint::Context->get('cashcard')) {
        return status_bad_request('no cashcard available');
    }

    my $basket = schema('cashpoint')->resultset('Basket')->create({
        cashcardid => Cashpoint::Context->get('cashcard'),
        date       => DateTime->now(time_zone => 'local'),
    });

    return status_created({id => $basket->id});
};

get qr{/baskets/([\d]+)} => protected valid_basket sub {
    my $basket = shift;

    return status_ok({
        items => $basket->items,
        value => $basket->value,
        creationdate => $basket->date->datetime,
    });
};

del qr{/baskets/([\d]+)} => protected valid_basket sub {
    my $basket = shift;

    eval {
        schema('cashpoint')->txn_do(sub {
            $basket->delete_related('BasketItems');
            $basket->delete;
        });
    };

    return send_error('internal error', 500) if ($@); # FIXME: log
    return status_ok();
};

get qr{/baskets/([\d]+)/items} => protected valid_basket sub {
    my $basket = shift;

    my @data = ();
    my $items = $basket->search_related('BasketItems');
    while (my $i = $items->next) {
        push @data, {
            id          => $i->id,
            productid   => $i->product->id,
            conditionid => $i->condition->id,
            price       => $i->price,
        };
    }

    return status_ok(\@data);
};

post qr{/baskets/([\d]+)/items} => protected valid_basket sub {
    my $basket = shift;

    (my $ean = params->{ean} || "") =~ s/^\s+|\s+$//g;

    my @errors = ();
    my $product;
    if (!defined $ean || length $ean > 13 || !validate_ean($ean)) {
        push @errors, 'invalid ean';
    } elsif (!($product = schema('cashpoint')->resultset('Product')->find({ ean => $ean}))) {
        push @errors, 'invalid product';
    }

    return status_bad_request(\@errors) if @errors;

    my $price = $product->price($basket->cashcard, $basket->get_item_quantity($product));
    return status_bad_request('product currently not available for sale') unless $price;

    my $credit = $basket->cashcard->credit;
    if ($credit - $basket->value - $price->value < 0) {
        return status_bad_request('insufficient credit balance')
    }

    my $item = $basket->create_related('BasketItems', {
        productid   => $product->id,
        conditionid => $price->condition,
        price       => $price->value,
    });

    return status_created({
        id        => $item->id,
        name      => $product->name,
        price     => $price->value,
        condition => $price->condition,
    });
};

del qr{/baskets/([\d]+)/items/([\d]+)} => protected valid_basket sub {
    my $basket = shift;
    my (undef, $itemid) = splat;

    my $item = $basket->find_related('BasketItems', {
        basketitemid => $itemid,
    });

    return status_not_found('item not found') unless $item;

    $item->delete;
    return status_ok();
};

put qr{/baskets/([\d]+)/checkout} => protected valid_basket sub {
    my $basket = shift;

    schema('cashpoint')->txn_do(sub {
        # create sale
        my $sale = schema('cashpoint')->resultset('Sale')->create({
            cashcardid => $basket->cashcard->id,
            total      => $basket->value,
            saledate   => DateTime->now(time_zone => 'local'),
            basketdate => $basket->date,
        });

        # create sale items out of basket items
        my $items = $basket->search_related('BasketItems')->search({});
        while (my $i = $items->next) {
            schema('cashpoint')->resultset('SaleItem')->create({
                saleid      => $sale->id,
                conditionid => $i->condition->id,
                productid   => $i->product->id,
                price       => $i->price,
            });

            # update stock
            $i->product->stock($i->product->stock - 1);
            $i->product->update;
        }

        # subtract credit
        $sale->cashcard->create_related('Credit', {
            chargingtype => 2,
            amount       => - $basket->value,
            date         => DateTime->now(time_zone => 'local'),
        });

        $items->delete;
        $basket->delete;
    });

    return send_error('an error occured, please try again later') if $@;
    return status_ok();
};

42;
