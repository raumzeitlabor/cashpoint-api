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
use Log::Log4perl qw( :easy );

use Cashpoint::Context;
use Cashpoint::CashcardGuard;
use BenutzerDB::User;
use BenutzerDB::Auth;

get '/cashcards' => protected sub {
    my @cashcards = schema('cashpoint')->resultset('Cashcard')->ctx_ordered;
    return status_ok(\@cashcards);
};

post '/cashcards' => protected 'admin', sub {
    # check if connection to benutzerdb is alive
    eval { database; };
    if ($@) {
        ERROR 'could not connect to BenutzerDB: '.$@;
        return status(503);
    }

    my ($user, $group, $code, $pin) = map { s/^\s+|\s+$//g if $_; $_ }
        (params->{user}, params->{group}, params->{code}, params->{pin});

    my @errors = ();
    if (!defined $user || !isint($user) || !get_user($user)) {
        push @errors, 'invalid user';
    }
    if (!defined $group || (!isint($group) || $group == 0
            || !schema('cashpoint')->resultset('Group')->find($group))) {
        push @errors, 'group invalid or not found';
    }
    if (!defined $code || $code !~ /^[a-z0-9]{18}$/i || schema('cashpoint')
            ->resultset('Cashcard')->find({ code => $code})) {
        push @errors, 'invalid code';
    }
    if (!defined $pin || $pin !~ /^\d{6}$/i) {
        push @errors, 'invalid pin';
    }

    return status_bad_request(\@errors) if @errors;

    schema('cashpoint')->resultset('Cashcard')->create({
        groupid        => $group,
        userid         => $user,
        code           => $code,
        pin            => $pin,
        activationdate => DateTime->now(time_zone => 'local'),
    });

    INFO 'creating new cashcard '.$code.' for user '.$user
        .' (by user '.Cashpoint::Context->get('userid').')';

    return status_created();
};

put qr{/cashcards/([a-zA-Z0-9]{18})/(dis|en)able} => protected 'admin', valid_cashcard sub {
    my $cashcard = shift;
    my (undef, $mode) = splat;

    $cashcard->update({disabled => $mode eq 'en' ? 0 : 1});

    INFO ($mode eq 'en' ? 'enabling' : 'disabling').' cashcard '.$cashcard->code
        .' of user '.$cashcard->user.' (by user '.Cashpoint::Context->get('userid').')';

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

    my $userid = $cashcard->user if $cashcard->pin == $pin;

    if (!defined $userid) {
        WARN 'unlocking of card '.$cashcard->code.' failed (wrong pin?)';
        return status(401);
    } elsif ($userid != $cashcard->user) {
        WARN 'unlocking of card '.$cashcard->code.' failed (cashcard owner '
            .$cashcard->user.' does not match session owner '.$userid.')';
        return status(401);
    }

    INFO 'card '.$cashcard->code.' unlocked by user '.Cashpoint::Context->get('userid');

    # save cashcardid in session to mark it as unlocked
    my $sessionid = Cashpoint::Context->get('sessionid');
    schema('cashpoint')->resultset('Session')->find($sessionid)->update({
        code       => $cashcard->code,
        cashcardid => $cashcard->id,
    });

    return status_ok();
};

get qr{/cashcards/([a-zA-Z0-9]{18})/transfers} => protected valid_cashcard sub {
    my $cashcard = shift;
    my @data = $cashcard->transfers;
    return status_ok(\@data);
};

post qr{/cashcards/([a-zA-Z0-9]{18})/transfers} => protected valid_enabled_cashcard sub {
    my $cashcard = shift;

    # check if cashcard is unlocked
    if (not defined Cashpoint::Context->get('cashcard') ||
            ( defined Cashpoint::Context->get('cashcard') &&
              Cashpoint::Context->get('cashcard') ne $cashcard->code )) {
        WARN 'refusing transfer for session '
            .Cashpoint::Context->get('sessionid').'; cashcard not unlocked';
        return status_bad_request('no cashcard available');
    }

    my ($recipient, $amount, $reason) = map { s/^\s+|\s+$//g if $_; $_ }
        (params->{recipient}, params->{amount}, params->{reason});

    my @errors = ();
    if (!defined $recipient || $recipient !~ m/^[a-z0-9]{18}$/i) {
        push @errors, 'invalid recipient';
    }
    if (!defined $amount || !isnum($amount) || $amount <= 0 || (isfloat($amount)
            && sprintf("%.2f", $amount) ne $amount)) {
        push @errors, 'invalid amount';
    }
    if (!defined $reason || length ($reason) == 0 || length ($reason) > 50) {
        push @errors, 'invalid reason';
    }

    return status_bad_request(\@errors) if @errors;

    eval {
        $cashcard->transfer($recipient, $amount, $reason);
    };

    if ($@) {
        ERROR 'could not transfer credit from '.$cashcard->code.' to '
            .$recipient.' (amount '.$amount.'): '.$@;
        return status(500);
    }

    INFO 'card '.$cashcard->code.' transferred '.$amount.' EUR to '.$recipient
        .' by user '.Cashpoint::Context->get('userid');

    return status_created();
};

get qr{/cashcards/([a-zA-Z0-9]{18})/credits} => protected valid_cashcard sub {
    my $cashcard = shift;
    return status_ok({
        balance => $cashcard->balance,
        status  => $cashcard->disabled == 0 ? "released" : "frozen",
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

    $amount = sprintf("%.2f", $amount);
    my $credit = $cashcard->create_related('Credit', {
        chargingtype => $type || 1,
        remark       => $remark || undef,
        amount       => $amount,
        balance      => $cashcard->balance + $amount,
        date         => DateTime->now(time_zone => 'local'),
    });

    INFO 'card '.$cashcard->code.' charged with '.$amount.' EUR by user '
        .Cashpoint::Context->get('userid');

    return status_created();
};

42;
