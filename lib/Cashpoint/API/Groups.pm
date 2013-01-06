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
    # i don't think we'll allow this
    return status_bad_request();

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

42;
