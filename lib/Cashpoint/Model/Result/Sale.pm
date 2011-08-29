#!/usr/bin/perl

package Cashpoint::Model::Result::Sale;

use strict;
use warnings;

use base qw/DBIx::Class::Core/;

__PACKAGE__->table('sale');
__PACKAGE__->add_columns(
    saleid => {
        accessor  => 'sale',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
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

    date => {
        data_type => 'datetime',
        is_nullable => 0,
    },

    total => {
        data_type => 'float',
        is_numeric => 1,
        is_nullable => 0,
    },

);

__PACKAGE__->set_primary_key('saleid');
__PACKAGE__->has_many('SaleItems' => 'Cashpoint::Model::Result::SaleItem', 'itemid');

1;
