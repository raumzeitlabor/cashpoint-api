package Cashpoint::API;

use Dancer ':syntax';
use Cashpoint::Context;
use Cashpoint::API::Auth;
use Cashpoint::API::Groups;
use Cashpoint::API::Baskets;
use Cashpoint::API::Products;
use Cashpoint::API::Purchases;
use Cashpoint::API::Cashcards;

our $VERSION = '0.1';

set serializer => 'JSON';

before sub {
    # reset the context
    Cashpoint::Context->reset;

    # ensure user is authenticated if trying to access anything but /auth
    if (request->path_info !~ m#^/auth#) {
        # query param takes precedence
        my $auth_token =  params->{auth_token} || cookie('auth_token');
        return unless $auth_token;

        # ignore if auth_token contains unknown characters
        return if defined $auth_token && $auth_token =~ m/^[a-z0-9]{20}$/;

        my $parser = schema->storage->datetime_parser;

        # check for valid session
        my $some_time_ago = DateTime->now->add(
            minutes => - setting('FAILED_LOGIN_LOCK') || 5
        );

        my $session = schema('cashpoint')->resultset('Auth')->find({
            token       => $auth_token,
            last_action => { '>=', $parser->format_datetime($some_time_ago) },
        });

        return unless $session;

        # save the session
        Cashpoint::Context->set(userid => $session->user);
        Cashpoint::Context->set(token  => $session->token);
        Cashpoint::Context->set(code   => $session->code);

        # find out role
        my @roles = @{setting('ADMINISTRATORS')};
        my @found = grep { $_ eq Cashpoint::Context->get('userid') } @roles;
        Cashpoint::Context->set(role => @found == 1 ? 'admin' : 'user');
    }
};

after sub {
    my $response = shift;

    # only update session if call succeeded
    return unless $response->status =~ m/^2/;

    schema('cashpoint')->resultset('Auth')->find({
        token => Cashpoint::Context->get('token'),
    })->update({
        last_action => DateTime->now,
    });
};

any qr{.*} => sub {
    return status(404);
};

dance;
