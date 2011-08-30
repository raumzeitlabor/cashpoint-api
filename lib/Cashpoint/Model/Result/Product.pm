package Cashpoint::Model::Result::Product;

use strict;
use warnings;

use base qw/DBIx::Class::Core/;

__PACKAGE__->load_components(qw/InflateColumn::DateTime/);
__PACKAGE__->table('product');
__PACKAGE__->add_columns(
    productid => {
        accessor  => 'product',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },

    ean => {
        data_type => 'varchar',
        is_nullable => 0,
        size => 20,
    },

    name => {
        data_type => 'varchar',
        is_nullable => 0,
        size => 30,
    },

    threshold => {
        data_type => 'integer',
        is_numeric => 1,
        is_nullable => 0,
        default_value => \'0',
    },

    added_on => {
        data_type => 'datetime',
        is_nullable => 0,
    },
);

sub stock {
    my $self = shift;
    return $self->search_related('Purchases', {})->get_column('amount')->sum || 0;
};

__PACKAGE__->set_primary_key('productid');
__PACKAGE__->has_many('Purchases' => 'Cashpoint::Model::Result::Purchase', 'productid');
__PACKAGE__->has_many('SaleItems' => 'Cashpoint::Model::Result::SaleItem', 'productid');
__PACKAGE__->has_many('Conditions' => 'Cashpoint::Model::Result::Condition', 'productid');

1;
