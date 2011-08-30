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
    my $group = schema()->resultset('Group')->search({groupid => params->{id}})
        ->single;
    return status_not_found('group not found') unless $group;
    $group->delete;

    # xxx: check if deleted
    return status_ok();
};

42;
