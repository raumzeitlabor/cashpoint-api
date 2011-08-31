package Cashpoint::Model::Result::PriceCache;

use strict;
use warnings;

use base qw/DBIx::Class::Core/;

__PACKAGE__->load_components(qw/InflateColumn::DateTime/);
__PACKAGE__->table('pricecache');
__PACKAGE__->add_columns(
    entryid => {
        accessor  => 'entry',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },

    productid => {
        accessor => 'product',
        data_type => 'integer',
        is_nullable => 0,
    },

    conditionid => {
        accessor => 'condition',
        data_type => 'integer',
        is_nullable => 0,
    },
);

__PACKAGE__->set_primary_key('entryid');
__PACKAGE__->belongs_to('productid' => 'Cashpoint::Model::Result::Product');
__PACKAGE__->belongs_to('conditionid' => 'Cashpoint::Model::Result::Condition');

42;
