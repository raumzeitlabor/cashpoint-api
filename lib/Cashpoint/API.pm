package Cashpoint::API;

use diagnostics;

use Dancer ':syntax';
use Dancer::Cookies;
use Dancer::Plugin::DBIC;

use Log::Log4perl qw( :easy );

use Cashpoint::Context;
use Cashpoint::API::Auth;
use Cashpoint::API::Groups;
use Cashpoint::API::Baskets;
use Cashpoint::API::Products;
use Cashpoint::API::Purchases;
use Cashpoint::API::Cashcards;
use Cashpoint::Model::QueryLogger;

our $VERSION = '0.1';

BEGIN {
    binmode STDIN, ":utf8";
    binmode STDOUT, ":utf8";
    binmode STDERR, ":utf8";
}

set serializer => 'JSON';

# hook custom storage statistic into dbix
schema('cashpoint')->storage->debugobj(Cashpoint::Model::QueryLogger->new());
schema('cashpoint')->storage->debug($ENV{DBIC_TRACE}||0);

INFO "Cashpoint-API starting up";

hook 'before' => sub {
    # log request?
    INFO request->method.' => '.request->path.' (by '.request->address.')';

    # reset the context
    Cashpoint::Context->reset;

    # query param > header > cookie
    my $auth_token = params->{auth_token};
    $auth_token  ||= request->header('auth_token');
    $auth_token  ||= cookie('auth_token');
    return unless $auth_token;

    # ignore if auth_token contains unknown characters
    return if defined $auth_token && $auth_token =~ m/^[a-z0-9]{20}$/;

    # check for valid session
    my $some_time_ago = DateTime->now(time_zone => 'local')->add(
        minutes => - setting('FAILED_LOGIN_LOCK') || 5
    );

    my $parser = schema->storage->datetime_parser;
    my $session = schema('cashpoint')->resultset('Session')->find({
        token       => $auth_token,
        last_action => { '>=', $parser->format_datetime($some_time_ago) },
        expired     => 0,
    });

    return unless $session;

    # save the session
    Cashpoint::Context->set(sessionid  => $session->id);
    Cashpoint::Context->set(userid     => $session->user);
    Cashpoint::Context->set(token      => $session->token);

    # before adding the cashcard to the context, check whether it's enabled
    if ($session->cashcard && $session->cashcard->disabled == 0) {
        Cashpoint::Context->set(cashcard => $session->cashcard);
    }

    # find out role
    my @roles = @{setting('ADMINISTRATORS')};
    my @found = grep { $_ eq Cashpoint::Context->get('userid') } @roles;
    Cashpoint::Context->set(role => @found == 1 ? 'admin' : 'user');
};

hook 'after' => sub {
    my $response = shift;

    # only update session if call succeeded
    return unless $response->status =~ m/^2/;

    # only update session if signed in at all
    return if not defined Cashpoint::Context->get('sessionid');

    DEBUG 'setting session cookie';

    #my $valid_until = DateTime->now(time_zone => 'local')->add(
    #    minutes => setting('FAILED_LOGIN_LOCK') || 5,
    #);
    my $valid_until = DateTime->now(time_zone => 'local');

    # update last_action time
    schema('cashpoint')->resultset('Session')->find({
        sessionid => Cashpoint::Context->get('sessionid'),
    })->update({
        last_action => $valid_until,
    });

    # try to set cookie
    (my $hostname = request->host) =~ s/:\d+//;
    set_cookie(
        auth_token => Cashpoint::Context->get('token'),
        expires    => time + (setting('FAILED_LOGIN_LOCK') || 5)*60,
        domain     => $hostname,
    );
};

any qr{.*} => sub {
    return status(404);
};

42;
