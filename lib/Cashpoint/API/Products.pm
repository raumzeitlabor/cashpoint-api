package Cashpoint::API;

use strict;
use warnings;

use Data::Dumper;
use Dancer ':syntax';
use Dancer::Plugin::REST;
use Dancer::Plugin::DBIC;

use Scalar::Util::Numeric qw/isnum/;
use Log::Log4perl qw( :easy );

use Cashpoint::Context;
use Cashpoint::Utils qw/validate_ean generate_ean/;
use Cashpoint::AccessGuard;
use Cashpoint::ProductGuard;

get '/products' => protected sub {
    my $products = schema('cashpoint')->resultset('Product')->ordered;

    my @data = ();
    while (my $p = $products->next) {
        push @data, {
            name     => $p->name,
            ean      => $p->ean,
            stock    => int($p->stock),
            added_on => $p->added_on->datetime,
        };
    }

    return status_ok(\@data);
};

post '/products' => protected 'admin', sub {
    my @errors = ();

    my ($name, $ean, $threshold, $composite) = map { s/^\s+|\s+$//g if $_; $_ }
        (params->{name}, params->{ean}, params->{threshold}, params->{composite});

    if (!defined $name || length $name > 30) {
        push @errors, 'invalid name';
    }
    if (defined $composite && (ref $composite ne 'ARRAY'
        || scalar @$composite <= 1)) {
        push @errors, 'invalid composite elements';
    }
    if (defined $composite && defined $ean) {
        push @errors, 'composite product must not have ean';
    } elsif (defined $ean && (length $ean != 13 || !validate_ean($ean))) {
        push @errors, 'invalid ean';
    } elsif (schema('cashpoint')->resultset('Product')->find({ ean => $ean})) {
        push @errors, 'product already exists';
    }
    if (defined $threshold && (!isint($threshold) || $threshold <= 0)) {
        push @errors, 'invalid threshold';
    }

    return status_bad_request(\@errors) if @errors;

    # if composite, check ean and units of all elements
    my @element_eans = ();
    foreach my $element (@{$composite}) {
        if (!defined $element->{ean} || !validate_ean($element->{ean})
            || !schema('cashpoint')->resultset('Product')->search({
                ean => $element->{ean} })->count) {
            return status_bad_request('invalid composite element');
        }
        if (!isnum ($element->{units}) || $element->{units} <= 0) {
            return status_bad_request('invalid composite element');
        }
        push @element_eans, $element->{ean};
    }

    # TODO: check if composite with same element combination exists

    # create a new, unallocated ean
    if ($composite) {
        my $rs;
        do {
            $ean = generate_ean;
            $rs = schema('cashpoint')->resultset('Product')->find({ ean => $ean });
        } while ($rs);

        DEBUG "generated ean $ean for composite product";
    }

    schema('cashpoint')->txn_do(sub {
        my $product = schema('cashpoint')->resultset('Product')->create({
            ean       => $ean,
            name      => $name,
            threshold => $threshold || 0,
            added_on  => DateTime->now(time_zone => 'local'),
        });

        # if composite, create composite relations
        foreach my $element (@{$composite}) {
            $product->add_to_composites({
                productid => $product,
                elementid => $element->{ean},
                units     => $element->{units},
            });
        }

        INFO 'user '.Cashpoint::Context->get('userid').' added new product '
            .$name.' ('.$product->id.')';
    });

    return status_created({ean => $ean}) if $composite;
    return status_created();
};

get qr{/products/([0-9]{13}|[0-9]{8})} => protected valid_product sub {
    my $product = shift;

    return status_ok({
        name      => $product->name,
        ean       => $product->ean,
        added_on  => $product->added_on->datetime,
        stock     => $product->stock,
        threshold => $product->threshold,
    });
};

get qr{/products/([0-9]{13}|[0-9]{8})/price} => protected valid_product sub {
    my $product = shift;

    my $cashcard = Cashpoint::Context->get('cashcard');
    return status_bad_request('invalid cashcard') if (!defined $cashcard);

    # price for one single unit
    my $price = $product->price($cashcard);

    return status_not_found('no price available') unless $price;
    return status_ok({price => $price->value, condition => $price->condition});
};

get qr{/products/([0-9]{13}|[0-9]{8})/conditions} => protected 'admin', valid_product sub {
    my $product = shift;

    my $parser = schema('cashpoint')->storage->datetime_parser;
    my $conditions = $product->search_related('Conditions', {
        startdate => { '<=', $parser->format_datetime(DateTime->now) },
        -or => [
            enddate => undef,
            enddate => { '>=', $parser->format_datetime(DateTime->now) },
        ],
    }, {
        order_by => { -asc => 'startdate' },
    });

    my @data = ();
    while (my $c = $conditions->next) {
        push @data, {
            condition  => $c->id,
            group      => $c->group->id,
            user       => $c->user,
            quantity   => $c->quantity,
            comment    => $c->comment,
            premium    => $c->premium,
            fixedprice => $c->fixedprice,
            startdate  => $c->startdate->datetime,
            enddate    => $c->enddate ? $c->enddate->datetime : undef,
        };
    }

    return status_ok(\@data);
};

post qr{/products/([0-9]{13}|[0-9]{8})/conditions} => protected 'admin', valid_product sub {
    my $product = shift;

    my ($group, $user, $quantity, $comment, $premium, $fixedprice, $startdate, $enddate)
        = map { s/^\s+|\s+$//g if $_; $_ } (
            params->{group},
            params->{user},
            params->{quantity},
            params->{comment},
            params->{premium},
            params->{fixedprice},
            params->{startdate},
            params->{enddate},
        );

    my ($sdate, $edate);
    eval { $sdate = Time::Piece->strptime($startdate || "invalid", "%d-%m-%Y"); };
    $sdate += $sdate->localtime->tzoffset unless $@;
    eval { $edate = Time::Piece->strptime($enddate || "invalid", "%d-%m-%Y"); };
    $edate += $edate->localtime->tzoffset unless $@;

    my @errors = ();
    if (!defined $group || (!isint($group) || $group == 0
            || !schema('cashpoint')->resultset('Group')->find($group))) {
        push @errors, 'invalid group';
    }
    if (defined $user && (!isint($user) || $user == 0)) {
        push @errors, 'invalid user';
    }
    if (defined $quantity && (!isint($quantity) || $quantity == 0)) {
        push @errors, 'invalid quantity';
    }
    if (defined $comment && ($comment eq '' || length $comment > 50)) {
        push @errors, 'invalid comment';
    }
    if (!defined $premium && !defined $fixedprice) {
        push @errors, 'invalid condition type';
    }
    if (defined $premium && (!isnum($premium) || $premium < 0)) {
        push @errors, 'invalid premium';
    }
    if (defined $fixedprice && (!isnum($fixedprice) || (isfloat($fixedprice)
            && sprintf("%.2f", $fixedprice) ne $fixedprice) || $fixedprice <= 0)) {
        push @errors, 'invalid fixedprice';
    }
    if (defined $startdate && ($startdate eq '' || !$sdate)) {
        push @errors, 'invalid startdate';
    }
    if (defined $enddate && ($enddate eq '' || !$edate)) {
        push @errors, 'invalid enddate';
    }

    return status_bad_request(\@errors) if @errors;

    my $condition = $product->create_related('Conditions', {
        groupid     => $group,
        userid      => $user ? $user : undef,
        quantity    => $quantity || 1,
        comment     => $comment,
        premium     => $premium,
        fixedprice  => $fixedprice,
        startdate   => $sdate ? $sdate->datetime : DateTime->now(time_zone => 'local'),
        enddate     => $edate ? $edate->datetime : undef,
    });

    INFO 'user '.Cashpoint::Context->get('userid').' added new condition '
        .$condition->id.' for product '.$product->name.' ('.$product->id.')';

    return status_created();
};

42;
