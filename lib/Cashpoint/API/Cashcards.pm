package Cashpoint::API;

use strict;
use warnings;

use Data::Dumper;
use Dancer ':syntax';
use Dancer::Plugin::REST;
use Dancer::Plugin::DBIC;

use DateTime;
use Scalar::Util::Numeric qw/isfloat/;

our $VERSION = '0.1';

set serializer => 'JSON';

get '/cashcards' => sub {
    my $cashcards = schema('cashpoint')->resultset('Cashcard')->ordered;

    my @data = ();
    while (my $c = $cashcards->next) {
        push @data, {
            code         => $c->code,
            group        => $c->group->id,
            user         => $c->user,
            activated_on => $c->activationdate->datetime,
            disabled     => $c->disabled,
        };
    }

    return status_ok(\@data);
};

post '/cashcards' => sub {
    my @errors = ();

    my ($code, $user, $group) = map { s/^\s+|\s+$//g if $_; $_ }
        (params->{code}, params->{user}, params->{group});

    # FIXME: validate user
    if (!$code || $code !~ /^[a-z0-9]{18}$/i || schema('cashpoint')
            ->resultset('Cashcard')->find({ code => $code})) {
        push @errors, 'invalid code';
    }
    if (defined $user && (!isint($user) || $user == 0)) {
        push @errors, 'invalid user';
    }
    if (!defined $group || (!isint($group) || $group == 0
            || !schema('cashpoint')->resultset('Group')->find($group))) {
        push @errors, 'group invalid or not found';
    }

    return status_bad_request(\@errors) if @errors;

    schema('cashpoint')->resultset('Cashcard')->create({
        code           => $code,
        groupid        => $group,
        userid         => $user,
        activationdate => DateTime->now,
    });

    return status_created();
};

put qr{/cashcards/([a-zA-Z0-9]{18})/disable} => sub {
    my ($code) = splat;
    my $cashcard = schema('cashpoint')->resultset('Cashcard')->find({
        code => $code,
    });
    return status_not_found("cashcard not found") unless $cashcard;
    return status_bad_request("cashcard already disabled") if $cashcard->disabled;

    $cashcard->update({disabled => 1});
    return status_ok();
};

put qr{/cashcards/([a-zA-Z0-9]{18})/enable} => sub {
    my ($code) = splat;
    my $cashcard = schema('cashpoint')->resultset('Cashcard')->find({
        code => $code,
    }) || return status_not_found("cashcard not found");
    return status_bad_request("cashcard already enabled") unless $cashcard->disabled;

    $cashcard->update({disabled => 0});
    return status_ok();
};

get qr{/cashcards/([a-zA-Z0-9]{18})/credit} => sub {
    my ($code) = splat;
    my $cashcard = schema('cashpoint')->resultset('Cashcard')->find({
        code => $code,
    }) || return status_not_found("cashcard not found");

    return status_ok({
        amount => $cashcard->credit,
        status => $cashcard->disabled == 0 ? "released" : "frozen",
    });
};

post qr{/cashcards/([a-zA-Z0-9]{18})/credit} => sub {
    my ($code) = splat;
    my $cashcard = schema('cashpoint')->resultset('Cashcard')->find({
        code => $code,
    }) || return status_not_found("cashcard not found");
    return status_bad_request("cashcard disabled") if $cashcard->disabled;

    my ($type, $remark, $amount) = map { s/^\s+|\s+$//g if $_; $_ }
        (params->{type}, params->{remark}, params->{amount});

    my @errors = ();
    if (defined $type && $type != 0 && $type != 1) { # 0 = init, 1 = charge
        push @errors, 'invalid charge type';
    }
    if ($remark && length $remark > 50) {
        push @errors, 'invalid remark';
    }
    if (!defined $amount || !isnum($amount) || (isfloat($amount)
            && sprintf("%.2f", $amount) ne $amount)) {
        push @errors, 'invalid amount';
    }

    return status_bad_request(\@errors) if @errors;

    my $credit = $cashcard->create_related('Credit', {
        chargingtype => $type || 1,
        remark       => $remark || undef,
        amount       => sprintf("%.2f", $amount),
        date         => DateTime->now,
    });

    # lock card if credit is negative and lock it if necessary
    if ($cashcard->credit < 0) {
        $cashcard->disabled(1);
        $cashcard->update;
    }

    return status_ok();
};

42;
