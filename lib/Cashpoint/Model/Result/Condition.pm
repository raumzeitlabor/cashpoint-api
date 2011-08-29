#!/usr/bin/perl

package Cashpoint::Model::Result::Condition;

use strict;
use warnings;

use base qw/DBIx::Class::Core/;

__PACKAGE__->load_components(qw/InflateColumn::DateTime/);
__PACKAGE__->table('condition');
__PACKAGE__->add_columns(
    conditionid => {
        accessor  => 'condition',
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
        is_nullable => 1,
    },

    productid => {
        accessor  => 'product',
        data_type => 'integer',
        is_nullable => 1,
    },

    quantity => {
        data_type => 'integer',
        is_nullable => 1,
        is_numeric => 1,
    },

    comment => {
        data_type => 'varchar',
        size      => 50,
        is_nullable => 1,
    },

    premium => {
        data_type => 'float',
        is_numeric => 1,
        is_nullable => 1,
    },

    fixedprice => {
        data_type => 'float',
        is_numeric => 1,
        is_nullable => 1,
    },

    startdate => {
        data_type => 'datetime',
        is_nullable => 0,
    },

    startdate => {
        data_type => 'datetime',
        is_nullable => 1,
    },

);

__PACKAGE__->set_primary_key('conditionid');
__PACKAGE__->belongs_to('productid' => 'Cashpoint::Model::Result::Product');

1;
