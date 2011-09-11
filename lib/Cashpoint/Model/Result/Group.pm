package Cashpoint::Model::Result::Group;

use strict;
use warnings;

use base qw/DBIx::Class::Core/;

__PACKAGE__->table('groups');
__PACKAGE__->add_columns(
    groupid => {
        accessor  => 'group',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },

    name => {
        data_type => 'varchar',
        size      => 30,
        is_nullable => 0,
    },
);

__PACKAGE__->set_primary_key('groupid');
__PACKAGE__->has_many('Memberships', 'Cashpoint::Model::Result::Membership', 'groupid');

42;
