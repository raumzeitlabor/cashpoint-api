#!/usr/bin/perl

package Cashpoint::Model::Result::Cashcard;

use strict;
use warnings;

use base qw/DBIx::Class::Core/;

__PACKAGE__->table('cashcard');
__PACKAGE__->add_columns(
    cardid => {
        accessor  => 'card',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },

    code => {
        data_type => 'varchar',
        size      => 30,
        is_nullable => 0,
    },

    groupid => {
        accessor => 'group',
        data_type => 'integer',
        is_nullable => 0,
    },

    userid => {
        accessor => 'user',
        data_type => 'integer',
        is_nullable => 0,
    },

    activationdate => {
        data_type => 'datetime',
        is_nullable => 0,
    },

    disabled => {
        data_type => 'boolean',
        default_value => 0,
    },
);

__PACKAGE__->set_primary_key('cardid');
__PACKAGE__->has_many('credit' => 'Cashpoint::Model::Result::Credit', 'creditid');

1;
