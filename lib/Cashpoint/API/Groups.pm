package Cashpoint::API;

use strict;
use warnings;

use Data::Dumper;
use Dancer ':syntax';
use Dancer::Plugin::REST;
use Dancer::Plugin::DBIC;

use DateTime;
use Scalar::Util::Numeric qw/isint/;

our $VERSION = '0.1';

set serializer => 'JSON';

get '/groups' => sub {
    my $groups = schema('cashpoint')->resultset('Group')->ordered;

    my @data = ();
    while (my $g = $groups->next) {
        push @data, {
            group => $g->group,
            name  => $g->name,
        };
    };

    return status_ok(\@data);
};

post '/groups' => sub {
    (my $name = params->{name} || "") =~ s/^\s+|\s+$//g;

    my @errors = ();
    if (!$name || length $name > 30) {
        push @errors, 'invalid group name';
    }

    return status_bad_request(\@errors) if @errors;

    my $group = schema('cashpoint')->resultset('Group')->create({
        name  => $name,
    });

    return status_created({id => $group->id});
};

del qr{/groups/([\d]+)} => sub {
    my ($groupid) = splat;
    my $group = schema('cashpoint')->resultset('Group')->find($groupid);
    return status_not_found('group not found') unless $group;

    $group->delete;
    return status_ok();
};

get qr{/groups/([\d]+)/memberships} => sub {
    my ($groupid) = splat;
    my $group = schema('cashpoint')->resultset('Group')->find($groupid);
    return status_not_found('group not found') unless $group;

    my $memberships = schema('cashpoint')->resultset('Membership')->search({
        groupid => $groupid,
    }, {
        order_by => { -asc => 'membershipid' },
    });

    my @data = ();
    while (my $m = $memberships->next) {
        push @data, {
            id   => $m->id,
            user => $m->user,
        };
    }

    return status_ok(\@data);
};

post qr{/groups/([\d]+)/memberships} => sub {
    my ($groupid) = splat;
    my $group = schema('cashpoint')->resultset('Group')->find($groupid);
    return status_not_found('invalid group') unless $group;

    (my $user = params->{user} || "") =~ s/^\s+|\s+$//g;

    my @errors = ();
    # FIXME: validate user
    if (!defined $user || !isint($user) || $user == 0) {
        push @errors, 'invalid user';
    } else {
        my $already = schema('cashpoint')->resultset('Membership')->find({
            groupid => $groupid,
            userid  => $user,
        });

        if ($already) {
            push @errors, 'user is already member of that group';
        }
    }

    return status_bad_request(\@errors) if @errors;

    my $membership = schema('cashpoint')->resultset('Membership')->create({
        groupid => $groupid,
        userid  => $user,
    });

    return status_created({id => $membership->id});
};

del qr{/groups/([\d]+)/memberships/([\d]+)} => sub {
    my ($groupid, $membershipid) = splat;
    my $group = schema('cashpoint')->resultset('Group')->find($groupid);
    return status_not_found('group not found') unless $group;

    # watch out: use search instead of find, because we need to match the group again
    my $membership = schema('cashpoint')->resultset('Membership')->search({
        membershipid => $membershipid,
        groupid      => $groupid,
    });

    return status_not_found('membership not found') unless $membership->count;

    $membership->delete;
    return status_ok();
};

42;
