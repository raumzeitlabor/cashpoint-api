package Cashpoint::API;

use strict;
use warnings;

use Data::Dumper;
use Dancer ':syntax';
use Dancer::Plugin::REST;
use Dancer::Plugin::DBIC;
use Log::Log4perl qw( :easy );

use DateTime;
use Algorithm::CheckDigits;

use Cashpoint::AccessGuard;
use Cashpoint::BasketGuard;

post '/baskets' => protected sub {
    unless (Cashpoint::Context->get('cashcard')) {
        WARN 'refusing to create new basket for session '
            .Cashpoint::Context->get('sessionid').'; cashcard not unlocked';
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

    if ($@) {
        ERROR 'could not delete basket: '.$@;
        return send_error('internal error', 500);
    }
    return status_ok();
};

get qr{/baskets/([\d]+)/items} => protected valid_basket sub {
    my $basket = shift;

    my @data = ();
    my $items = $basket->search_related('BasketItems');
    while (my $i = $items->next) {
        push @data, {
            id          => $i->id,
            product     => $i->product->id,
            condition   => $i->condition->id,
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

    # we don't check for stock. if a product could be scanned, it obviously is
    # available, isn't it?

    my $price = $product->price($basket->cashcard,
        $basket->get_item_quantity($product)+1);

    return status_not_found('no price could be determined') unless $price;

    my $balance = $basket->cashcard->balance;
    if ($balance - $basket->value - $price->value < 0) {
        WARN 'not enough credit available on cashcard '.$basket->cashcard->code
            .'; '.($balance - $basket->value - $price->value).' EUR missing';
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
    INFO 'deleted basket item '.$itemid;
    return status_ok();
};

put qr{/baskets/([\d]+)/checkout} => protected valid_basket sub {
    my $basket = shift;

    INFO 'checking out basket '.$basket->id.' of cashcard '
        .$basket->cashcard->code.' (user '.$basket->cashcard->userid.')';

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

    if ($@) {
        return send_error('an error occured, please try again later');
        ERROR 'could not checkout basket; transaction failed! '.$@;
    }

    return status_ok();
};

42;
