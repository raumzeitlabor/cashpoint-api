package Cashpoint::Model::Result::Membership;

use strict;
use warnings;

use base qw/DBIx::Class::Core/;

__PACKAGE__->table('membership');
__PACKAGE__->add_columns(
    membershipid => {
        accessor  => 'membership',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },

    userid => {
        accessor  => 'user',
        data_type => 'integer',
        is_nullable => 0,
    },

    groupid => {
        accessor => 'groupid',
        data_type => 'integer',
        is_nullable => 0,
    },
);

__PACKAGE__->set_primary_key('membershipid');
__PACKAGE__->belongs_to('groupid' => 'Cashpoint::Model::Result::Group');

1;
