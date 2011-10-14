package Cashpoint::Model::Result::Product;

use strict;
use warnings;

use base qw/DBIx::Class::Core/;

use Cashpoint::Model::Price;
use Dancer::Plugin::DBIC;
use Log::Log4perl qw( :easy );

use POSIX qw(ceil);

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

    stock => {
        accessor => '_stock',
        data_type => 'integer',
        is_numeric => 1,
        is_nullable => 0,
        default_value => \'0',
    },

    threshold => {
        data_type => 'integer',
        is_numeric => 1,
        is_nullable => 0,
        default_value => \'0',
    },

    added_on => {
        data_type => 'datetime',
        timezone => 'local',
        is_nullable => 0,
    },
);

# in case this product is a composite product, we calculate the stock
# by choosing min(prod_1, ..., prod_n) for all products in the composite
sub stock {
    my $self = shift;
    my $composites = $self->composites;

    if ($composites->count) {
        my $min_stock = undef;
        while (my $p = $composites->next) {
            $min_stock = $min_stock
                ? ($p->stock < $min_stock ? $p->stock : $min_stock)
                : $p->stock;
        }
        return $min_stock;
    }

    return $self->_stock;
}

# determines the price of the product. in case the product is a composite, the
# price is determined by calculating the sum of the prices for each of the
# composite elements. in case any of the elements prices are undefined, the
# composite product's price cannot be determined and thus too evalutes to undef
sub price {
    my ($self, $cashcard, $quantity) = @_;

    # if no quantity was applied, we assume a qty of 1
    $quantity ||= 1;

    # check if we are a composite product and return the sum if so
    my $composites = $self->composites;
    if ($composites->count) {
        my $price = 0;
        while ($p = $composites->next) {
            my $pprice = $p->price($cashcard, $quantity*$p->units);
            return undef unless $pprice;
            $price += $pprice;
        }
        return $price;
    }

    # if no conditions have been explicitly defined for this product, there
    # may be a default condition for the group of the user, so we also look
    # for it. however, these conditions have lower priority than product
    # conditions.
    my $parser = schema->storage->datetime_parser;
    my $conditions = schema->resultset('Condition')->search({
        -and => [
            -or => [
                productid => $self->id,
                productid => undef,
            ],
            -or => [
                groupid => $cashcard->group->id,
                groupid => undef,
            ],
            -or => [
                userid => $cashcard->user,
                userid => undef,
            ],
            -or => [
                quantity => { '>=', $quantity },
                quantity => undef,
            ],
            startdate => { '<=', $parser->format_datetime(DateTime->now) },
            -or => [
                enddate => { '>=', $parser->format_datetime(DateTime->now) },
                enddate => undef,
            ],
        ],
    }, {
        order_by => { -desc => qw/productid groupid userid quantity startdate/ },
    });

    unless ($conditions->count) {
        ERROR 'could not calculate price for product '.$self->name
            .' ('.$self->id.'); no valid conditions could be found';
        return undef;
    }

    DEBUG 'condition context for '.$self->name.' ('.$self->id.') is ['
        .join(",", $conditions->get_column('id')->all()).']';

    # FIXME: use weighted average?
    my $base = $self->search_related('Purchases', {
    }, {
        #+select  => [ \'me.price/me.amount' ],
        #+as      => [ qw/unitprice/ ],
        order_by => { -desc => 'purchaseid' },
        rows     => 5,
    })->get_column('price')->func('AVG');

    WARN 'could not calculate base (no purchases found) for product '
        .$self->name.' ('.$self->id.')';

    # FIXME: calculate prices for all conditions and cache them?
    # prices are always rounded up to the tenth digit for moar profit
    my $c = $conditions->first;
    if (defined $base && $c->premium && $c->fixedprice) {
        DEBUG 'using PREMIUM&FIXEDPRICE for price calculation';
        return Cashpoint::Model::Price->new($c->id, sprintf("%.1f0",
            ceil(($base*$c->premium+$c->fixedprice)/0.1)*0.1));
    } elsif (defined $base && $c->premium && !$c->fixedprice) {
        DEBUG 'using PREMIUM mode for price calculation';
        return Cashpoint::Model::Price->new($c->id, sprintf("%.1f0",
            ceil($base*$c->premium/0.1)*0.1));
    } elsif (!$c->premium && $c->fixedprice) {
        DEBUG 'using FIXEDPRICE mode for price calculation';
        return Cashpoint::Model::Price->new($c->id, sprintf("%.1f0",
            ceil($c->fixedprice/0.1)*0.1));
    }

    ERROR 'no valid pricing mode could be found';
    return undef;
};

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
    $sqlt_table->add_index(name => 'eanindex', fields => ['ean']);
}

__PACKAGE__->set_primary_key('productid');
__PACKAGE__->has_many(composites => 'Cashpoint::Model::Result::CompositeProduct',
    { 'foreign.compositeid' => 'self.productid' });
__PACKAGE__->has_many('Purchases' => 'Cashpoint::Model::Result::Purchase',
    'productid', { order_by => { -desc => 'purchaseid' }});
__PACKAGE__->has_many('SaleItems' => 'Cashpoint::Model::Result::SaleItem',
    'productid', { order_by => { -desc => 'itemid' }});
__PACKAGE__->has_many('Conditions' => 'Cashpoint::Model::Result::Condition',
    'productid', { order_by => { -desc => [qw/userid groupid/]}});

42;
