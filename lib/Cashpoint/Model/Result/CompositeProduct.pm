package Cashpoint::Model::Result::CompositeProduct;

use strict;
use warnings;

use base qw/DBIx::Class::Core/;
use Cashpoint::Model::Result::Product;

__PACKAGE__->table('compositeproduct');
__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },

    productid => {
        data_type => 'integer',
        is_nullable => 0,
    },

    elementid => {
        data_type => 'integer',
        is_nullable => 0,
    },

    units => {
        data_type => 'integer',
        is_nullable => 0,
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to('parent' => 'Cashpoint::Model::Result::Product',
    { 'foreign.productid' => 'self.productid' });
__PACKAGE__->belongs_to('element' => 'Cashpoint::Model::Result::Product',
    { 'foreign.productid' => 'self.elementid' }, {
        proxy => [ Cashpoint::Model::Result::Product->columns ],
    });

42;
