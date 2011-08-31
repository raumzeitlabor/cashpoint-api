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

get '/groups' => sub {
    my $groups = schema->resultset('Group')->search({}, {
        order_by => { -asc => 'groupid' }
    });

    my @data = ();
    while (my $g = $groups->next) {
        push @data, {
            groupid => $g->group,
            name    => $g->name,
        };
    };

    return status_ok(\@data);
};

post '/groups' => sub {
    my @errors = ();

    if (0) {
    } if (!params->{name} || params->{name} !~ /^.{1,30}$/) {
        push @errors, 'group name must be between 1 and 30 characters long';
    }

    return status_bad_request(\@errors) if @errors;

    my $group = schema->resultset('Group')->create({
        name  => params->{name},
    });

    return status_created({id => $group->id});
};

del '/groups/:id' => sub {
    my $group = schema()->resultset('Group')->find({groupid => params->{id}});
    return status_not_found('group not found') unless $group;
    $group->delete;

    # xxx: check if deleted
    return status_ok();
};

get '/groups/:id/memberships' => sub {
    my $group = schema()->resultset('Group')->find({groupid => params->{id}});
    return status_not_found('group not found') unless $group;

    my $memberships = schema->resultset('Membership')->search({
        groupid => $group->id,
    }, {
        order_by => { -asc => 'membershipid' },
    });

    my @data = ();
    while (my $m = $memberships->next) {
        push @data, {
            membershipid => $m->id,
            userid       => $m->user,
        };
    }

    return status_ok(\@data);
};

post '/groups/:id/memberships' => sub {
    my $group = schema()->resultset('Group')->find({groupid => params->{id}});
    return status_not_found('group not found') unless $group;

    my @errors = ();
    if (0) {
    } if (!params->{userid} || params->{userid} !~ m/^\d+$/) {
        push @errors, 'userid is required';
    } if (!params->{userid} || params->{groupid} !~ m/^\d+$/) {
        push @errors, 'groupid is required';
    } if (schema->resultset('Membership')->find({ groupid => params->{groupid},
        userid  => params->{userid}})) {
        @errors = ('user is already member of that group');
    }

    return status_bad_request(\@errors) if @errors;

    my $membership = schema->resultset('Membership')->create({
        groupid => params->{groupid},
        userid  => params->{userid},
    });

    return status_created({membershipid => $membership->id});
};

del '/groups/:id/memberships/:id' => sub {

};

42;
