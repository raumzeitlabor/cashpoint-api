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

    if ($auth_mode == 1 && (!defined $code || $code !~ /^[a-z0-9]{18}$/i)) {
        push @errors, 'invalid code';
    } else {
        $cashcard = schema('cashpoint')->resultset('Cashcard')->find({
            code     => $code,
            disabled => 0,
        });

        push @errors, 'invalid code' unless $cashcard;
    }
    if ($auth_mode == 1 && (!defined $pin || !isint($pin))) {
        push @errors, 'invalid pin';
    }

    return status_bad_request(\@errors) if @errors;

    my ($userid, $auth);
    my $parser = schema->storage->datetime_parser;
    if ($auth_mode == 1) {

        # check for failed login attempts within last five minutes
        my $five_mins_ago = DateTime->now->add( minutes => -5 );
        my $fails = schema('cashpoint')->resultset('Auth')->search({
            code       => $code,
            login_date => { '>=', $parser->format_datetime($five_mins_ago) },
            token      => undef,
        });

        return status(403) if $fails->count == 3;

        # log the attempt to the database
        $auth = schema('cashpoint')->resultset('Auth')->create({
            code       => $code,
            auth_mode  => $auth_mode,
            login_date => DateTime->now,
        });

        $userid = auth_by_pin($cashcard->user, $pin);

        # the user is not authorized for this card
        return status(401) if (defined $userid && $cashcard->user != $userid);

    } elsif ($auth_mode == 2) {

        # check for failed login attempts within last five minutes
        my $five_mins_ago = DateTime->now->add( minutes => -5 );
        my $fails = schema('cashpoint')->resultset('Auth')->search({
            username   => $username,
            login_date => { '>=', $parser->format_datetime($five_mins_ago) },
            token      => undef,
        });

        return status(403) if $fails->count == 3;

        # log the attempt to the database
        $auth = schema('cashpoint')->resultset('Auth')->create({
            username   => $username,
            auth_mode  => $auth_mode,
            login_date => DateTime->now,
        });

        $userid = auth_by_passwd($username, $passwd);
    }

    return status(401) unless defined $userid;

    # mark the auth information as valid
    my $token = generate_token();
    $auth->user($userid);
    $auth->token($token);
    $auth->last_action(DateTime->now);
    $auth->update();

    return {user => int($userid), role => 'user', auth_token => $token};
};

42;
