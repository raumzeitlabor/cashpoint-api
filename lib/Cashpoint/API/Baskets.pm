package Cashpoint::API;

use strict;
use warnings;

use Data::Dumper;
use Dancer ':syntax';
use Dancer::Plugin::REST;
use Dancer::Plugin::DBIC;

use DateTime;

our $VERSION = '0.1';

set serializer => 'JSON';

post '/baskets' => sub {
    my @errors = ();
    if (!params->{cashcard}) {
        push @errors, 'invalid cashcard specified';
    }

    my $cashcard;
    unless ($cashcard = schema('cashpoint')->resultset('Cashcard')
            ->find({ code => params->{cashcard}, disabled => 0, })) {
        @errors = 'cashcard not found or disabled';
    }

    return status_bad_request(\@errors) if @errors;

    my $basket = schema('cashpoint')->resultset('Basket')->create({
        cashcardid => $cashcard->id,
        date       => DateTime->now,
    });

    return status_created({id => $basket->id});
};

get '/baskets/:id' => sub {
    my $basket = schema('cashpoint')->resultset('Basket')->find({
        basketid => params->{id},
    });

    return status_not_found('basket not found') unless $basket;

    my @errors = ();
    if (!params->{cashcard}) {
        push @errors, 'no cashcard specified';
    }

    my $cashcard;
    if ($basket->cashcard->code ne params->{cashcard} || $basket->cashcard->disabled == 1) {
        @errors = 'invalid cashcard or cashcard disabled';
    }

    return status_bad_request(\@errors) if @errors;

    return status_ok({
        items => $basket->items,
        value => $basket->value,
        creationdate => $basket->date->datetime,
    });
};

del '/baskets/:id' => sub {
    my $basket = schema('cashpoint')->resultset('Basket')->find({
        basketid => params->{id},
    });

    return status_not_found('basket not found') unless $basket;

    my @errors = ();
    if (!params->{cashcard}) {
        push @errors, 'no cashcard specified';
    }

    my $cashcard;
    if ($basket->cashcard->code ne params->{cashcard}
        || $basket->cashcard->disabled == 1) {
        @errors = 'invalid cashcard or cashcard disabled';
    }

    return status_bad_request(\@errors) if @errors;

    eval {
        schema('cashpoint')->txn_do(sub {
            $basket->delete_related('BasketItems');
            $basket->delete;
        });
    };

    return send_error('internal error', 500) if ($@); # FIXME: log
    return status_ok();
};

get '/baskets/:id/items' => sub {
    my $basket = schema('cashpoint')->resultset('Basket')->find({
        basketid => params->{id},
    });

    return status_not_found('basket not found') unless $basket;

    my @errors = ();
    if (!params->{cashcard}) {
        push @errors, 'no cashcard specified';
    }

    my $cashcard;
    if ($basket->cashcard->code ne params->{cashcard}
        || $basket->cashcard->disabled == 1) {
        @errors = 'invalid cashcard or cashcard disabled';
    }

    return status_bad_request(\@errors) if @errors;

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

post '/baskets/:id/items' => sub {
    my $basket = schema('cashpoint')->resultset('Basket')->find({
        basketid => params->{id},
    });

    return status_not_found('basket not found') unless $basket;

    my @errors = ();
    my ($cashcard, $product);

    if (0) {
    } if (!params->{cashcard}) {
        push @errors, 'no cashcard specified';
    } elsif (!($cashcard = schema('cashpoint')->resultset('Cashcard')
            ->find({ code => params->{cashcard}, disabled => 0, }))) {
        return status_bad_request('cashcard not found or disabled');
    } if ($basket->cashcard->code ne params->{cashcard}) {
        return status_bad_request('invalid cashcard');
    } if (!params->{ean} || params->{ean} !~ /^[a-z0-9]{5,30}/i) {
        push @errors, 'invalid ean specified';
    } elsif (!($product = schema('cashpoint')->resultset('Product')
            ->find({ ean => params->{ean}}))) {
        return status_bad_request('product not found');
    }

    return status_bad_request(\@errors) if @errors;

    my $price = $product->price($cashcard, $basket->get_item_quantity($product));
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

    return status_created({id => $item->id});
};

del '/baskets/:id/items/:itemid' => sub{
    my $basket = schema('cashpoint')->resultset('Basket')->find({
        basketid => params->{id},
    });

    return status_not_found('basket not found') unless $basket;

    my @errors = ();

    if (0) {
    } if (!params->{cashcard}) {
        push @errors, 'no cashcard specified';
    } elsif (!schema('cashpoint')->resultset('Cashcard')
            ->find({ code => params->{cashcard}, disabled => 0, })) {
        return status_bad_request('cashcard not found or disabled');
    } if ($basket->cashcard->code ne params->{cashcard}) {
        return status_bad_request('invalid cashcard');
    }

    return status_bad_request(\@errors) if @errors;

    my $item = $basket->find_related('BasketItems', {
        basketitemid => params->{itemid},
    });

    return status_not_found('item not found') unless $item;

    $item->delete;
    return status_ok();
};

put '/baskets/:id/checkout' => sub {
    my $basket = schema('cashpoint')->resultset('Basket')->find({
        basketid => params->{id},
    });

    return status_not_found('basket not found') unless $basket;

    my @errors = ();
    my $cashcard;

    if (0) {
    } if (!params->{cashcard}) {
        push @errors, 'no cashcard specified';
    } elsif (!($cashcard = schema('cashpoint')->resultset('Cashcard')
            ->find({ code => params->{cashcard}, disabled => 0, }))) {
        return status_bad_request('cashcard not found or disabled');
    } if ($basket->cashcard->code ne params->{cashcard}) {
        return status_bad_request('invalid cashcard');
    }
    return status_bad_request(\@errors) if @errors;

    schema('cashpoint')->txn_do(sub {
        # create sale
        my $sale = schema('cashpoint')->resultset('Sale')->create({
            cashcardid => $basket->cashcard->id,
            total      => $basket->value,
            saledate   => DateTime->now,
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
            date         => DateTime->now,
        });

        $items->delete;
        $basket->delete;
    });

    return status_bad_request('an error occured, please try again later') if $@;
    return status_ok();
};

42;
