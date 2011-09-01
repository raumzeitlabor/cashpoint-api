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
            groupid        => $c->group->id,
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
    } if (!params->{code} || params->{code} !~ /^[a-z0-9]{5,30}$/i) {
        push @errors, 'code must be at least 5 and up to 30 chars long';
    } if (!defined params->{userid} || params->{userid} !~ /^\d+$/) {
        push @errors, 'userid is required or must be set to 0 for anonymous cards';
        # FIXME: also check if userid exists?
    } if (!params->{groupid} || !schema->resultset('Group')->search({
            groupid => params->{groupid}})->count) {
        push @errors, 'groupid is missing or group does not exist';
    } if (schema->resultset('Cashcard')->search({ code => params->{code}})->count) {
        @errors = ('code is already in use');
    }

    return status_bad_request(\@errors) if @errors;

    schema->resultset('Cashcard')->create({
        code           => params->{code},
        groupid        => params->{groupid},
        userid         => params->{userid}, # FIXME
        activationdate => DateTime->now,
    });

    return status_created();
};

put '/cashcards/:code/disable' => sub {
    my $cashcard = schema()->resultset('Cashcard')->find({code => params->{code}});
    return status_not_found("cashcard does not exist") unless $cashcard;
    return status_bad_request("cashcard already disabled") if $cashcard->disabled;

    $cashcard->update({disabled => 1});
    return status_ok();
};

put '/cashcards/:code/enable' => sub {
    my $cashcard = schema()->resultset('Cashcard')->find({code => params->{code}});
    return status_not_found("cashcard does not exist") unless $cashcard;
    return status_bad_request("cashcard already enabled") unless $cashcard->disabled;

    $cashcard->update({disabled => 0});
    return status_ok();
};

get '/cashcards/:code/credit' => sub {
    my $cashcard = schema()->resultset('Cashcard')->find({code => params->{code}});
    return status_not_found("cashcard does not exist") unless $cashcard;

    return status_ok({
        amount => $cashcard->credit,
        status => $cashcard->disabled == 0 ? "released" : "frozen",
    });
};

post '/cashcards/:code/credit' => sub {
    my $cashcard = schema()->resultset('Cashcard')->find({code => params->{code}});
    return status_not_found("cashcard does not exist") unless $cashcard;

    my @errors = ();
    # type, remark, amount
    if (0) {
    } if (!params->{type} || params->{type} !~ /^[0,1]$/) { # 0 = init, 1 = charge
        push @errors, 'invalid charge type';
    } if (params->{remark} && params->{remark} !~ /^.{1,50}$/) {
        push @errors, 'maximum length of remark is 50 chars';
    } if (!params->{amount} || !isnum(params->{amount})) {
        push @errors, 'invalid amount';
    }

    return status_bad_request(\@errors) if @errors;

    my $credit = $cashcard->create_related('Credit', {
        chargingtype => params->{type},
        remark       => params->{remark} || undef,
        amount       => sprintf("%.2f", params->{amount}),
        date         => DateTime->now,
    });

    return status_ok({id => $credit->id});
};

del '/cashcards/:code/credit/:id' => sub {
    my $cashcard = schema()->resultset('Cashcard')->find({code => params->{code}});
    return status_not_found("cashcard does not exist") unless $cashcard;

    my $credit = $cashcard->search_related('Credit', { creditid => params->{id}});
    return status_not_found('credit not found') unless $credit;

    $credit->delete;
    return status_ok();
};

42;
