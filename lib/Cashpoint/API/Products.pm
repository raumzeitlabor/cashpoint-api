package Cashpoint::API;

use strict;
use warnings;

use Data::Dumper;
use Dancer ':syntax';
use Dancer::Plugin::REST;
use Dancer::Plugin::DBIC;

use Scalar::Util::Numeric qw/isnum/;
use Log::Log4perl qw( :easy );

use Cashpoint::Utils qw/validate_ean/;
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

    my ($name, $ean, $threshold) = map { s/^\s+|\s+$//g if $_; $_ }
        (params->{name}, params->{ean}, params->{threshold});

    if (!defined $name || length $name > 30) {
        push @errors, 'invalid name';
    }
    if (!defined $ean || length $ean > 13 || !validate_ean($ean)) {
        push @errors, 'invalid ean';
    } elsif (schema('cashpoint')->resultset('Product')->find({ ean => $ean})) {
        push @errors, 'product already exists';
    }
    if (defined $threshold && (!isint($threshold) || $threshold <= 0)) {
        push @errors, 'invalid threshold';
    }

    return status_bad_request(\@errors) if @errors;

    my $product = schema('cashpoint')->resultset('Product')->create({
        ean       => $ean,
        name      => $name,
        threshold => $threshold || 0,
        added_on  => DateTime->now(time_zone => 'local'),
    });

    INFO 'user '.Cashpoint::Context->get('userid').' added new product '
        .$name.' ('.$product->id.')';

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

    my $cashcardid = Context::Cashcard->get('cashcard');
    if (!defined $cashcardid) {
        status_bad_request('invalid cashcard');
    }

    # look up cashcard
    my $cashcard = schema('cashpoint')->resultset('Cashcard')->find($cashcardid);

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
    eval { $sdate = Time::Piece->strptime($startdate || 0, "%d-%m-%Y"); };
    $sdate += $sdate->localtime->tzoffset unless $@;
    eval { $edate = Time::Piece->strptime($enddate || 0, "%d-%m-%Y"); };
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
    if (defined $premium && !isnum($premium)) {
        push @errors, 'invalid premium';
    }
    if (defined $fixedprice && (!isnum($fixedprice) || (isfloat($fixedprice)
            && sprintf("%.2f", $fixedprice) ne $fixedprice))) {
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
        startdate   => $sdate->datetime || DateTime->now(time_zone => 'local'),
        enddate     => $edate->datetime,
    });

    INFO 'user '.Cashpoint::Context->get('userid').' added new condition '
        .$condition->id.' for product '.$product->name.' ('.$product->id.')';

    return status_created();
};

42;
