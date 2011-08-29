package Cashpoint::API;

use strict;
use warnings;

use Data::Dumper;
use Dancer ':syntax';
use Dancer::Plugin::REST;
use Dancer::Plugin::DBIC;

our $VERSION = '0.1';

set serializer => 'JSON';

get '/products/:ean' => sub {
    my $product = schema()->resultset('Product')->search({ean => params->{ean}})
        ->single;
    return status_not_found('product not found') unless $product;
    return status_ok({
        name      => $product->name,
        ean       => $product->ean,
        #threshold => $product->threshold,
    });
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
    } if (schema->resultset('Product')->search({ ean => params->{ean}})->count) {
        @errors = ('product already exists');
    }

    return status_bad_request(\@errors) if @errors;

    schema->resultset('Product')->create({
        ean       => params->{ean},
        name      => params->{name},
        threshold => params->{threshold} || 0,
        added_on  => time,
    });

    # xxx: check if inserted
    return status_created();
};

del '/products/:ean' => sub {
    my $product = schema()->resultset('Product')->search({ean => params->{ean}})
        ->single;
    return status_not_found('product not found') unless $product;
    $product->delete;

    # xxx: check if deleted
    return status_ok();
};

42;
