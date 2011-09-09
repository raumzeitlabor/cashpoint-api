package Cashpoint::API;

use strict;
use warnings;

use Data::Dumper;
use Dancer ':syntax';
use Dancer::Plugin::REST;
use Dancer::Plugin::DBIC;

use Cashpoint::Utils qw/generate_token/;
use BenutzerDB::Auth;

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

    my @errors = ();
    my $cashcard;

    # validate input data
    if ($auth_mode == 1) {
        if (!defined $code || $code !~ /^[a-z0-9]{18}$/i) {
            push @errors, 'invalid code';
        } else {
            # check if the cashcard specified is valid
            $cashcard = schema('cashpoint')->resultset('Cashcard')->find({
                code     => $code,
                disabled => 0,
            });

            push @errors, 'invalid code' unless $cashcard;
        }

        if (!defined $pin || !isint($pin)) {
            push @errors, 'invalid pin';
        }
    } elsif ($auth_mode == 2) {
        push @errors, 'invalid password' unless (length $passwd);
        push @errors, 'invalid username' unless (length $username);
    }

    return status_bad_request(\@errors) if @errors;

    my ($userid, $auth);
    my @query_params = ();

    # define query parameters
    if ($auth_mode == 1) {
        @query_params = (code => $code);
    } elsif ($auth_mode == 2) {
        @query_params = (username => $username);
    }

    my $parser = schema->storage->datetime_parser;

    # check for failed login attempts within last five minutes
    my $some_time_ago = DateTime->now->add( minutes => - setting('FAILED_LOGIN_LOCK') || 5);
    my $fails = schema('cashpoint')->resultset('Auth')->search({
        @query_params,
        login_date => { '>=', $parser->format_datetime($some_time_ago) },
        token      => undef,
    });

    return status(403) if $fails->count == (setting('MAX_FAILED_ATTEMPTS') || 3);

    # log the attempt to the database
    $auth = schema('cashpoint')->resultset('Auth')->create({
        @query_params,
        auth_mode  => $auth_mode,
        login_date => DateTime->now,
    });

    $userid = auth_by_pin($cashcard->user, $pin) if $auth_mode == 1;
    $userid = auth_by_passwd($username, $passwd) if $auth_mode == 2;

    # the user is not authorized for this card
    if ($auth_mode == 1 && defined $userid && $cashcard->user != $userid) {
        return status(401);
    } elsif (not defined $userid) {
        return status(401);
    }

    # generate a valid token
    my $token;
    do {
        $token = generate_token();
    } while (schema('cashpoint')->resultset('Auth')->find({ token => $token }));

    # mark the auth information as valid
    $auth->user($userid);
    $auth->token($token);
    $auth->last_action(DateTime->now);
    $auth->update();

    # try to set cookie
    (my $hostname = request->host) =~ s/:\d+//;
    cookie(
        auth_token => $token,
        expires    => (time + setting('FAILED_LOGIN_LOCK')*60),
        domain     => $hostname,
    );

    return {user => int($userid), role => 'user', auth_token => $token};
};

42;
