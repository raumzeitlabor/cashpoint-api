#!/usr/bin/perl

package Cashpoint::Model::Result::SaleItem;

use strict;
use warnings;

use base qw/DBIx::Class::Core/;

__PACKAGE__->table('saleitem');
__PACKAGE__->add_columns(
    itemid => {
        accessor  => 'item',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },

    saleid => {
        accessor => 'sale',
        data_type => 'integer',
        is_nullable => 0,
    },

    conditionid => {
        accessor => 'condition',
        data_type => 'integer',
        is_nullable => 0,
    },

    productid => {
        accessor  => 'product',
        data_type => 'integer',
        is_nullable => 1,
    },

    amount => {
        data_type => 'integer',
        is_numeric => 1,
        is_nullable => 0,
    },

    sum => {
        data_type => 'float',
        is_numeric => 1,
        is_nullable => 0,
    },

);

__PACKAGE__->set_primary_key('itemid');
__PACKAGE__->belongs_to('saleid' => 'Cashpoint::Model::Result::Sale');
__PACKAGE__->belongs_to('conditionid' => 'Cashpoint::Model::Result::Condition');
__PACKAGE__->belongs_to('productid' => 'Cashpoint::Model::Result::Product');

1;
