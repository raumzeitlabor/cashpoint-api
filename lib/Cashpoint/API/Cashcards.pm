package Cashpoint::API;

use strict;
use warnings;

use Data::Dumper;
use Dancer ':syntax';
use Dancer::Plugin::REST;
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Database;

use DateTime;
use Scalar::Util::Numeric qw/isfloat/;

use Cashpoint::Context;
use Cashpoint::CashcardGuard;
use BenutzerDB::User;
use BenutzerDB::Auth;

our $VERSION = '0.1';

set serializer => 'JSON';

get '/cashcards' => protected sub {
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

post '/cashcards' => protected 'admin', sub {
    # check if connection to benutzerdb is alive
    eval { database; }; return status(503) if $@;

    my ($code, $user, $group) = map { s/^\s+|\s+$//g if $_; $_ }
        (params->{code}, params->{user}, params->{group});

    my @errors = ();
    if (!defined $code || $code !~ /^[a-z0-9]{18}$/i || schema('cashpoint')
            ->resultset('Cashcard')->find({ code => $code})) {
        push @errors, 'invalid code';
    }
    if (!defined $user || !isint($user) || !get_user($user)) {
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
        activationdate => DateTime->now(time_zone => 'local'),
    });

    return status_created();
};

put qr{/cashcards/([a-zA-Z0-9]{18})/(dis|en)able} => protected 'admin', valid_cashcard sub {
    my $cashcard = shift;
    my (undef, $mode) = splat;
    $cashcard->update({disabled => $mode eq 'en' ? 0 : 1});
    return status_ok();
};

put qr{/cashcards/([a-zA-Z0-9]{18})/unlock} => protected valid_enabled_cashcard sub {
    my $cashcard = shift;

    # if it is already unlocked, stop here.
    my $cardid = Cashpoint::Context->get('cardid');
    return status_ok() if (defined $cardid && $cashcard->id != $cardid);

    # check if pin is valid
    (my $pin = params->{pin} || "") =~ s/^\s+|\s+$//g;
    if (!$pin || $pin !~ /^\d+$/) {
        return status_bad_request('invalid pin');
    }

    # check if connection to benutzerdb is alive
    eval { database; }; return status(503) if $@;

    # validate pin
    my $userid = auth_by_pin($cashcard->user, $pin);

    if (!defined $userid || $userid != $cashcard->user) {
        return status(401);
    }

    my $authid = Cashpoint::Context->get('authid');
    schema('cashpoint')->resultset('Auth')->find($authid)->update({
        code       => $cashcard->code,
        cashcardid => $cashcard->id,
    });

    return status_ok();
};

get qr{/cashcards/([a-zA-Z0-9]{18})/credits} => protected 'admin', valid_cashcard sub {
    my $cashcard = shift;
    return status_ok({
        amount => $cashcard->credit,
        status => $cashcard->disabled == 0 ? "released" : "frozen",
    });
};

post qr{/cashcards/([a-zA-Z0-9]{18})/credits} => protected 'admin', valid_cashcard sub {
    my $cashcard = shift;

    my ($type, $remark, $amount) = map { s/^\s+|\s+$//g if $_; $_ }
        (params->{type}, params->{remark}, params->{amount});

    my @errors = ();
    if (defined $type && $type != 0 && $type != 1) { # 0 = init, 1 = charge
        push @errors, 'invalid charge type';
    }
    if (defined $remark && ($remark eq '' || length $remark > 50)) {
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
        date         => DateTime->now(time_zone => 'local'),
    });

    # lock card if credit is negative and lock it if necessary
    if ($cashcard->credit < 0) {
        $cashcard->disabled(1);
        $cashcard->update;
    }

    return status_ok();
};

42;
