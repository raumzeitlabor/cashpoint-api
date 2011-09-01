package Cashpoint::Model::Result::BasketItem;

use strict;
use warnings;

use base qw/DBIx::Class::Core/;

__PACKAGE__->load_components(qw/InflateColumn::DateTime/);
__PACKAGE__->table('basketitem');
__PACKAGE__->add_columns(
    basketitemid => {
        accessor  => 'basketitem',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },

    basketid => {
        accessor => 'basket',
        data_type => 'integer',
        is_numeric => 1,
        is_nullable => 0,
    },

    productid => {
        accessor => 'product',
        data_type => 'integer',
        is_numeric => 1,
        is_nullable => 0,
    },

    conditionid => {
        accessor => 'condition',
        data_type => 'integer',
        is_numeric => 1,
        is_nullable => 0,
    },

    price => {
        data_type => 'float',
        is_numeric => 1,
        is_nullable => 0,
    },
);

__PACKAGE__->set_primary_key('basketitemid');
__PACKAGE__->belongs_to('basketid' => 'Cashpoint::Model::Result::Basket');
__PACKAGE__->belongs_to('productid' => 'Cashpoint::Model::Result::Product');
__PACKAGE__->belongs_to('conditionid' => 'Cashpoint::Model::Result::Condition');

42;
