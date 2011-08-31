package Cashpoint::API;

use strict;
use warnings;

use Data::Dumper;
use Dancer ':syntax';
use Dancer::Plugin::REST;
use Dancer::Plugin::DBIC;

use Scalar::Util::Numeric qw/isnum/;

our $VERSION = '0.1';

set serializer => 'JSON';

get '/products' => sub {
    my $products = schema()->resultset('Product')->search({}, {
        order_by => { -asc => 'name' }
    });

    my @data = ();
    while (my $p = $products->next) {
        push @data, {
            name     => $p->name,
            ean      => $p->ean,
            stock    => $p->stock,
            added_on => $p->added_on->datetime,
        };
    }

    return status_ok(\@data);
};

post '/products' => sub {
    my @errors = ();

    if (0) {
    } if (!params->{name} || params->{name} !~ /^.{5,30}$/) {
        push @errors, 'name must be at least 5 and up to 30 chars long';
    } if (!params->{ean} || params->{ean} !~ /^.{5,30}$/) {
        push @errors, 'ean must be at least 5 and up to 20 chars long';
    } if (params->{threshold} && params->{threshold} !~ /^\d+$/) {
        push @errors, 'threshold must be greater than 0';
    } if (schema->resultset('Product')->find({ ean => params->{ean}})) {
        @errors = ('product already exists');
    }

    return status_bad_request(\@errors) if @errors;

    schema->resultset('Product')->create({
        ean       => params->{ean},
        name      => params->{name},
        threshold => params->{threshold} || 0,
        added_on  => DateTime->now,
    });

    # xxx: check if inserted
    return status_created();
};

get '/products/:ean' => sub {
    my $product = schema()->resultset('Product')->find({ean => params->{ean}});
    return status_not_found('product not found') unless $product;
    return status_ok({
        name      => $product->name,
        ean       => $product->ean,
        added_on  => $product->added_on->datetime,
        stock     => $product->stock,
        #threshold => $product->threshold,
    });
};

del '/products/:ean' => sub {
    my $product = schema()->resultset('Product')->find({ean => params->{ean}});
    return status_not_found('product not found') unless $product;
    $product->delete;

    # xxx: check if deleted
    return status_ok();
};

get '/products/:ean/price' => sub {
    my $product = schema()->resultset('Product')->find({ean => params->{ean}});
    return status_not_found('product not found') unless $product;

    my @errors = ();
    my $cashcard;

    if (0) {
    } if (!params->{cashcard} || params->{cashcard} !~ /^[a-z0-9]{5,30}$/i) {
        push @errors, 'cashcard code missing or illegal';
    } else {
        $cashcard = schema->resultset('Cashcard')->find({
            code     => params->{cashcard},
            disabled => 0
        });

        @errors = ('illegal cashcard or cashcard disabled') unless $cashcard;
    }

    return status_bad_request(\@errors) if @errors;

    my $price = $product->price($cashcard);
    return status_not_found('no price available') unless $price; # FIXME: not found?
    return status_ok({price => $price});
};

get '/products/:ean/conditions' => sub {
    my $product = schema()->resultset('Product')->find({ean => params->{ean}});
    return status_not_found('product not found') unless $product;

    my $parser = schema->storage->datetime_parser;
    my $conditions = $product->search_related('Conditions', {
#        -and => {
#            startdate   => {'>=' => $parser->format_datetime(DateTime->now)},
#            -or => {
#                enddate => {'<=' => $parser->format_datetime(DateTime->now)},
#                enddate => undef,
#            },
#        },
    }, {
        order_by => {-asc => 'startdate'},
    });

    my @data = ();
    while (my $c = $conditions->next) {
        push @data, {
            conditionid => $c->id,
            groupid     => $c->group->id,
            userid      => $c->user,
            quantity    => $c->quantity,
            comment     => $c->comment,
            premium     => $c->premium,
            fixedprice  => $c->fixedprice,
            startdate   => $c->startdate->datetime,
            enddate     => $c->enddate ? $c->enddate->datetime : undef,
        };
    }

    return status_ok(\@data);
};

post '/products/:ean/conditions' => sub {
    my $product = schema()->resultset('Product')->find({ean => params->{ean}});
    return status_not_found('product not found') unless $product;

    my ($sdate, $edate);
    eval { $sdate = Time::Piece->strptime(params->{startdate} || 0, "%d-%m-%Y"); };
    $sdate += $sdate->localtime->tzoffset;
    eval { $edate = Time::Piece->strptime(params->{enddate} || 0, "%d-%m-%Y"); };
    $edate += $edate->localtime->tzoffset;

    my @errors = ();
    if (0) {
    } if (!params->{groupid} || params->{groupid} !~ /^\d+$/) {
        push @errors, 'groupid is required';
    } if (!defined params->{userid} || params->{userid} !~ /^\d+$/) {
        push @errors, 'userid is required or must be set to 0';
    } if (params->{quantity} && (params->{quantity} !~ /^d+$/ || params->{quantity} == 0)) {
        push @errors, 'quantity must be greater zero if specified';
    } if (params->{comment} && params->{comment} !~ /^.{5,50}$/) {
        push @errors, 'comment must be at least 5 and up to 50 chars long if specified';
    } if (!params->{premium} && !params->{fixedprice}) {
        push @errors, 'one of premium, fixedprice or both must be specified';
    } if (params->{premium} && !isnum(params->{premium})) {
        push @errors, 'premium must be a decimal';
    } if (params->{fixedprice} && !isnum(params->{fixedprice})) {
        push @errors, 'fixedprice must be a decimal';
    } if (params->{startdate} && !$sdate) {
        push @errors, 'startdate must follow dd-mm-yyyy formatting';
    } if (params->{enddate} && !$edate) {
        push @errors, 'enddate must follow dd-mm-yyyy formatting';
    } if (params->{groupid} && !schema->resultset('Group')
        ->find({groupid => params->{groupid}})) {
        @errors = ('group does not exist');
    }

    return status_bad_request(\@errors) if @errors;

    $product->create_related('Conditions', {
        groupid     => params->{groupid},
        userid      => params->{userid} != 0 ? params->{userid} : undef,
        quantity    => params->{quantity} || 0,
        comment     => params->{comment} || undef,
        premium     => params->{premium} || undef,
        fixedprice  => params->{fixedprice} || undef,
        startdate   => params->{startdate} || DateTime->now,
        enddate     => params->{enddate} || undef,
    });

    return status_created();
};

del '/products/:ean/conditions/:id' => sub {
    my $product = schema()->resultset('Product')->find({ean => params->{ean}});
    return status_not_found('product not found') unless $product;

    my $condition = $product->find_related('Conditions', { conditionid => params->{id} });
    return status_not_found('condition not found') unless $condition;

    $condition->delete;

    # xxx: check if deleted
    return status_ok();
};

42;
