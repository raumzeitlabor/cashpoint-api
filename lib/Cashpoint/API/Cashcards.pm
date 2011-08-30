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

get '/cashcards' => sub {
    my $cashcards = schema()->resultset('Cashcard')->search({}, {});

    my @data = ();
    while (my $c = $cashcards->next) {
        push @data, {
            code           => $c->code,
            groupid        => $c->group,
            userid         => $c->user,
            activationdate => $c->activationdate->datetime,
            disabled       => $c->disabled,
        };
    }

    return status_ok(\@data);
};

post '/cashcards' => sub {
    my @errors = ();

    # FIXME: user/group
    # code group user activation disabled
    if (0) {
    } if (!params->{code} || params->{code} !~ /^.{5,30}$/) {
        push @errors, 'code must be at least 5 and up to 30 chars long';
    } if (schema->resultset('Cashcard')->search({ code => params->{code}})->count) {
        @errors = ('code is already in use');
    }

    return status_bad_request(\@errors) if @errors;

    schema->resultset('Cashcard')->create({
        code           => params->{code},
        groupid        => 0, # FIXME
        userid         => 0, # FIXME
        activationdate => DateTime->now,
    });

    return status_created();
};

put '/cashcards/:code/disable' => sub {
    my $cashcard = schema()->resultset('Cashcard')->search({code => params->{code}})
        ->single;
    return status_not_found("cashcard does not exist") unless $cashcard;

    return status_bad_request("cashcard already disabled") if $cashcard->disabled;

    $cashcard->update({disabled => 1});

    return status_ok();
};

put '/cashcards/:code/enable' => sub {
    my $cashcard = schema()->resultset('Cashcard')->search({code => params->{code}})
        ->single;
    return status_not_found("cashcard does not exist") unless $cashcard;

    return status_bad_request("cashcard already enabled") unless $cashcard->disabled;

    $cashcard->update({disabled => 0});

    return status_ok();
};

42;
