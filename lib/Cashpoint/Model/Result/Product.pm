package Cashpoint::Model::Result::Product;

use strict;
use warnings;

use base qw/DBIx::Class::Core/;

use Cashpoint::API::Pricing::Engine;
use Cashpoint::Model::Price;
use Dancer::Plugin::DBIC;

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

sub price {
    my ($self, $cashcard) = @_;

    # if no conditions have been explicitly defined for this product, there
    # may be a default condition for the group of the user, so we also look
    # for it. however, these conditions have lower priority than product
    # conditions.
    my $conditions = schema->resultset('Condition')->search({
        -and => [
            -or => [
                productid => $self->id,
                productid => undef,
            ],
            -or => [
                userid => $cashcard->user,
                userid => undef,
            ],
            groupid => $cashcard->group->id,
        ],
    }, {
    }); # FIXME: with valid date

    return undef unless $conditions->count;

    # FIXME: use weighted average?
    my $base = $self->search_related('Purchases', {
    }, {
        +select  => [ \'me.price/me.amount' ], # FIXME: is there a more elegant way?
        +as      => [ qw/unitprice/ ],
        order_by => { -desc => 'purchaseid' },
        rows     => 5,
    })->get_column('unitprice')->func('AVG');

    # FIXME: calculate prices for all conditions and cache them?
    while (my $c = $conditions->next) {
        if (0) {
        } elsif ($c->premium && $c->fixedprice) {
            return Cashpoint::Model::Price->new($c->id, sprintf("%.1f0",
                $base*$c->premium+$c->fixedprice)+0.0);
        } elsif ($c->premium && !$c->fixedprice) {
            return Cashpoint::Model::Price->new($c->id, sprintf("%.1f0",
                $base*$c->premium)+0.0);
        } elsif (!$c->premium && $c->fixedprice) {
            return Cashpoint::Model::Price->new($c->id, sprintf("%.1f0",
                $c->fixedprice)+0.0);
        }
        return undef;
    }
};

__PACKAGE__->set_primary_key('productid');
__PACKAGE__->has_many('Purchases' => 'Cashpoint::Model::Result::Purchase',
    'productid', { order_by => { -desc => 'purchaseid' }});
__PACKAGE__->has_many('SaleItems' => 'Cashpoint::Model::Result::SaleItem',
    'productid', { order_by => { -desc => 'itemid' }});
__PACKAGE__->has_many('Conditions' => 'Cashpoint::Model::Result::Condition',
    'productid', { order_by => { -desc => [qw/userid groupid/]}});

42;
