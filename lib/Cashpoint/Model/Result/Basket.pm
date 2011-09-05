package Cashpoint::Model::Result::Basket;

use strict;
use warnings;

use base qw/DBIx::Class::Core/;

__PACKAGE__->load_components(qw/InflateColumn::DateTime/);
__PACKAGE__->table('basket');
__PACKAGE__->add_columns(
    basketid => {
        accessor  => 'basket',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },

    cashcardid => {
        accessor => 'cashcard',
        data_type => 'integer',
        is_numeric => 1,
        is_nullable => 0,
    },

    date => {
        data_type => 'datetime',
        is_nullable => 0,
    },
);

sub value {
    my $self = shift;
    return $self->search_related('BasketItems', undef)->get_column('price')->sum || 0,
}

sub items {
    my $self = shift;
    return $self->search_related('BasketItems', undef)->count;
}

sub get_item_quantity {
    my ($self, $product) = @_;
    return $self->search_related('BasketItems', {
        product => $product->id
    })->count;
}

__PACKAGE__->set_primary_key('basketid');
__PACKAGE__->has_many('BasketItems' => 'Cashpoint::Model::Result::BasketItem', 'basketid');
__PACKAGE__->has_one('Cashcard' => 'Cashpoint::Model::Result::Cashcard', 'cashcardid');
__PACKAGE__->belongs_to('cashcardid' => 'Cashpoint::Model::Result::Cashcard');

42;
