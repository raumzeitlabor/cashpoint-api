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

42;
