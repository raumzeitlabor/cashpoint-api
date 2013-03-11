package Cashpoint::API;

use strict;
use warnings;

use Data::Dumper;
use Dancer ':syntax';
use Dancer::Plugin::REST;
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Database;
use Log::Log4perl qw( :easy );

use Cashpoint::Utils qw/generate_token/;
use Cashpoint::AccessGuard;
use Cashpoint::Context;

use BenutzerDB::Auth;
use BenutzerDB::User;

get '/auth' => protected 'admin', sub {
    return status_ok();
};

post '/auth' => sub {
    my ($code, $pin, $username, $passwd) = map { s/^\s+|\s+$//g if $_; $_ }
        (params->{code}, params->{pin}, params->{username}, params->{passwd});

    # 1 = PIN, 2 = USER/PW
    my $auth_mode = 0;

    if (defined $code && defined $pin && !defined $username && !defined $passwd) {
        $auth_mode = 1;
    } elsif (defined $username && defined $passwd && !defined $code && !defined $pin) {
        $auth_mode = 2;
    } else {
        return status_bad_request('invalid request');
    }

    # check if connection to benutzerdb is alive
    eval { database; };
    if ($@) {
        ERROR 'could not connect to BenutzerDB: '.$@;
        return status(503);
    }

    my @errors = ();
    my $cashcard;

    # validate input data
    if ($auth_mode == 1) {
        # XXX: i don't think we should use a fixed code length
        if (!defined $code) { #|| $code !~ /^[a-z0-9]{18}$/i) {
            push @errors, 'invalid code';
        } else {
            # check if the cashcard specified is valid
            $cashcard = schema('cashpoint')->resultset('Cashcard')->find({
                code     => $code,
                #disabled => 0,
            });

            # we allow registration of unused cashcards by logging in
            # with the BenutzerDB pin

            #push @errors, 'invalid code' unless $cashcard;
        }

        if (!defined $pin || !isint($pin)) {
            push @errors, 'invalid pin';
        }
    } elsif ($auth_mode == 2) {
        push @errors, 'invalid password' unless (length $passwd);
        push @errors, 'invalid username' unless (length $username);
    }

    return status_bad_request(\@errors) if @errors;

    my @query_params = ();

    # define query parameters
    if ($auth_mode == 1) {
        @query_params = (code => $code);
    } elsif ($auth_mode == 2) {
        @query_params = (username => $username);
    }

    INFO 'login attempt ',join(" => ", @query_params);

    # check for failed login attempts within last five minutes
    my $parser = schema->storage->datetime_parser;
    my $some_time_ago = DateTime->now(time_zone => 'local')->add(
        minutes => - setting('FAILED_LOGIN_LOCK') || 5
    );

    my $fails = schema('cashpoint')->resultset('Session')->search({
        @query_params,
        login_date => { '>=', $parser->format_datetime($some_time_ago) },
        token      => undef,
    });

    my ($toomanyfails, $userid, $auth);
    if ($fails->count >= (setting('MAX_FAILED_ATTEMPTS') || 3)) {
        ERROR 'login '.join(" => ", @query_params).' refused ('
            .$fails->count.' failed attempts).';
        $toomanyfails = $fails->count;
    } else {
        # $cashcard->user may be undef in case of auth by pin!
        my $cc_user = (defined $cashcard) ? $cashcard->user : undef;

        # if $cc_user is undef, lookup will be done based on pin only!
        # this works only because the pin is unique.
        if ($auth_mode == 1) {
            if (not defined $cashcard) {
                $userid = auth_by_pin($cc_user, $pin) if $auth_mode == 1;
            } else {
                $userid = $cashcard->user if $cashcard->pin == $pin;
            }
        } elsif ($auth_mode == 2) {
            $userid = auth_by_passwd($username, $passwd);
        }

        if (defined $userid) {
            # if the user was found in the database and the cashcard is
            # not yet in use, we register it to the user's account

            # this is a feature designed for transition only!
            if ($auth_mode == 1 and not defined $cashcard) {
                # let's first check if the user already has a cashcard for the
                # given group.
                my $has_cc = schema('cashpoint')->resultset('Cashcard')->search({
                    userid  => $userid,
                    groupid => 1,
                })->count;

                unless ($has_cc) {
                    $cashcard = schema('cashpoint')->resultset('Cashcard')->create({
                        code    => $code,
                        pin     => $pin,
                        userid  => $userid,
                        # we can safely assume that the user is a RZL-member
                        groupid => 1, # XXX: make sure the group exists
                        activationdate => $parser->format_datetime(DateTime->now),
                    });
                }
            }

            # check if there is already a valid session, in which case it'll be returned
            $auth = schema('cashpoint')->resultset('Session')->find({
                @query_params,
                login_date => { '>=', $parser->format_datetime($some_time_ago) },
                token      => { '!=', undef },
                userid     => $userid,
                expired    => 0,
            });

            INFO 'selecting existing session '.$auth->id
                .' for '.join(" => ", @query_params) if $auth;
        } else {
            if ($fails->count + 1 >= (setting('MAX_FAILED_ATTEMPTS') || 3)) {
                $toomanyfails = $fails->count;
            }
        }
    }

    # log this attempt if the session does not exist yet
    $auth = schema('cashpoint')->resultset('Session')->create({
        @query_params,
        auth_mode  => $auth_mode,
        login_date => DateTime->now(time_zone => 'local'),
    }) unless ($auth);

    # the user is not authorized for this card
    if ($toomanyfails) {
        return status(403);
    } elsif (not defined $userid) {
        ERROR 'login attempt '.join(" => ", @query_params).' failed'
            .' (attempt no '.$fails->count.')';
        status(401);
        return {attempts_left => (setting('MAX_FAILED_ATTEMPTS') || 3) - $fails->count};
    } elsif ($auth_mode == 1 && defined $userid && $cashcard->user != $userid) {
        ERROR 'login attempt '.join(" => ", @query_params).' failed'
            .' (cashcard not belonging to user '.$userid.','
            .' attempt no '.$fails->count.')';
        status(401);
        return {attempts_left => (setting('MAX_FAILED_ATTEMPTS') || 3) - $fails->count};
    }

    # delete all failed attempts in case this attempt succeeded
    DEBUG 'failed attempts: '.$fails->count;

    # token will be zero in case it is a new session
    if (not defined $auth->token) {
        DEBUG 'generating token for session '.$auth->id;

        # generate a valid token
        my $token;
        do {
            $token = generate_token();
        } while (schema('cashpoint')->resultset('Session')->find({
            token => $token
        }));

        # mark the auth information as valid
        $auth->user($userid);
        $auth->token($token);
        $auth->update();
    }

    # save cashcard id in case cashcard was authorized
    $auth->update({ cashcardid => $cashcard->id }) if $auth_mode == 1;

    # hint: last action will be automatically updated by after {} hook
    Cashpoint::Context->set('sessionid', $auth->id);
    Cashpoint::Context->set('token', $auth->token);

    # return the information
    my $valid_until = DateTime->now(time_zone => 'local')->add(
        minutes => setting('FAILED_LOGIN_LOCK') || 5
    )->datetime;

    # check the role
    my @roles = @{setting('ADMINISTRATORS')};
    my @found = grep { $_ eq $userid } @roles;

    return status_ok({
        user        => {
            id   => int($userid),
            name => get_user($userid)->{username},
        },
        role        => @found == 1 ? 'admin' : 'user',
        auth_token  => $auth->token,
        valid_until => $valid_until,
    });
};

del '/auth' => protected sub {
    # don't delete, but expire
    my $session = schema('cashpoint')->resultset('Session')->find(
        Cashpoint::Context->get('sessionid'),
    )->update({ expired => 1, });

    INFO 'expired session '.Cashpoint::Context->get('sessionid');

    # unset session id for after hook
    Cashpoint::Context->unset('sessionid');

    return status_ok();
};

42;
