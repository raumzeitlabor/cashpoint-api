package Cashpoint::API;

use strict;
use warnings;

use Data::Dumper;
use Dancer ':syntax';
use Dancer::Plugin::REST;
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Database;

use DateTime;
use Scalar::Util::Numeric qw/isint/;

use BenutzerDB::User;
use Cashpoint::AuthGuard;
use Cashpoint::GroupGuard;

our $VERSION = '0.1';

set serializer => 'JSON';

get '/groups' => authenticated 'admin', sub {
    my @groups = schema('cashpoint')->resultset('Group')->ordered;
    return status_ok(\@groups);
};

post '/groups' => authenticated 'admin', sub {
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

del qr{/groups/([\d]+)} => authenticated 'admin', valid_group sub {
    my $group  = shift;

    schema('cashpoint')->txn_do(sub {
        $group->delete_related('Memberships');
        $group->delete;
    });

    return status(500) if $@;
    return status_ok();
};

get qr{/groups/([\d]+)/memberships} => authenticated 'admin', valid_group sub {
    my $group  = shift;
    my @data = schema('cashpoint')->resultset('Membership')->ordered($group->id);
    return status_ok(\@data);
};

post qr{/groups/([\d]+)/memberships} => authenticated 'admin', valid_group sub {
    my $group = shift;
    (my $user = params->{user} || "") =~ s/^\s+|\s+$//g;

    # check if connection to benutzerdb is alive
    eval { database; }; return status(503) if $@;

    my @errors = ();
    if (!defined $user || !isint($user) || !get_user($user)) {
        push @errors, 'invalid user';
    } else {
        $group->find_related('Memberships', {
            userid  => $user,
        }) && push @errors, 'user is already member of that group';
    }

    return status_bad_request(\@errors) if @errors;

    my $membership = $group->create_related('Membership', {
        userid  => $user,
    });

    return status_created({id => $membership->id});
};

del qr{/groups/([\d]+)/memberships/([\d]+)} => authenticated 'admin', valid_group sub {
    my $group = shift;
    my (undef, $membershipid) = splat;

    # watch out: use search instead of find, because we need to match the group again
    my $membership = $group->search_related('Memberships', {
        membershipid => $membershipid,
    });

    return status_not_found('membership not found') unless $membership->count;

    $membership->delete;
    return status_ok();
};

42;
