package Cashpoint::API;

use strict;
use warnings;

use Encode;
use Data::Dumper;
use Dancer ':syntax';
use Dancer::Plugin::REST;
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Database;

use DateTime;
use Scalar::Util::Numeric qw/isint/;
use Log::Log4perl qw( :easy );

use BenutzerDB::User;
use Cashpoint::AccessGuard;
use Cashpoint::GroupGuard;

get '/groups' => protected 'admin', sub {
    my @groups = schema('cashpoint')->resultset('Group')->ordered;
    return status_ok(\@groups);
};

post '/groups' => protected 'admin', sub {
    (my $name = params->{name} || "") =~ s/^\s+|\s+$//g;

    my @errors = ();
    if (!$name || length $name > 30) {
        push @errors, 'invalid group name';
    }

    return status_bad_request(\@errors) if @errors;

    my $group = schema('cashpoint')->resultset('Group')->create({
        name  => $name,
    });

    INFO 'user '.Cashpoint::Context->get('userid').' creates new group "'.$name.'"';

    return status_created({id => $group->id});
};

del qr{/groups/([\d]+)} => protected 'admin', valid_group sub {
    my $group  = shift;

    schema('cashpoint')->txn_do(sub {
        $group->delete_related('Memberships');
        $group->delete;
    });

    if ($@) {
        ERROR 'could not delete group '.$group->name.' ('.$group->id.'): '.$@;
        return status(500);
    }

    INFO 'user '.Cashpoint::Context->get('userid').' deleted group '
        .$group->name.' ('.$group->id.')';

    return status_ok();
};

get qr{/groups/([\d]+)/memberships} => protected 'admin', valid_group sub {
    my $group  = shift;
    my @data = schema('cashpoint')->resultset('Membership')->ordered($group->id);
    return status_ok(\@data);
};

post qr{/groups/([\d]+)/memberships} => protected 'admin', valid_group sub {
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

    my $membership = $group->create_related('Memberships', {
        userid  => $user,
    });

    INFO 'user '.Cashpoint::Context->get('userid').' added user '.$user.' to'
        .' group '.$group->name.' ('.$group->id.')';

    return status_created({id => $membership->id});
};

del qr{/groups/([\d]+)/memberships/([\d]+)} => protected 'admin', valid_group sub {
    my $group = shift;
    my (undef, $membershipid) = splat;

    # watch out: use search instead of find, because we need to match the group again
    my $membership = $group->search_related('Memberships', {
        membershipid => $membershipid,
    });

    return status_not_found('membership not found') unless $membership->count;

    my ($userid, $groupid) = ($membership->userid, $membership->groupid);
    $membership->delete;

    INFO 'user '.Cashpoint::Context->get('userid').' removed user '
        .$userid.' from group '.$groupid;

    return status_ok();
};

42;
