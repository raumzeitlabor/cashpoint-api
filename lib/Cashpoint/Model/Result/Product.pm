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

# warning: these functions are by no means optimized for performance. beware!

# in case this product is a composite product, we calculate the stock
# by choosing min(prod_1, ..., prod_n) for all products in the composite
# in case of an update, we apply the stock change to all composite elements
# if the stock is ought to be updated, the method argument will be interpreted
# as a relative value; if the update is applied to a composite product, it is
# cascaded down to the composite elements incorporating the number of units
sub stock {
    my $self = shift;
    my $composites = $self->composites;

    # stock is going to be updated and this is not a composite product
    if (@_ and not $self->composites->count) {
        $self->_stock($self->_stock + shift);
        return;
    } elsif (@_) {
        while (my $p = $composites->next) {
            $self->stock($p->stock + shift * $p->units);
        }
        return;
    }

    # no update is to be done
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

# in case the product is a composite, the base for price calculation is the sum
# of the last X elements' purchase amounts. otherwise, the base is the average
# of the last X purchase amounts. in case there are no purchases for one of the
# composite elements, the base for the composite too cannot be determined.
sub base {
    my $self = shift;
    my $composites = $self->composites;

    if ($composites->count) {
        my $base = 0;
        while (my $p = $composites->next) {
            my $ebase = $p->base;
            return undef unless $ebase;
            $base += $ebase;
        }
        return $base;
    }

    return $self->search_related('Purchases', {
    }, {
        #+select  => [ \'me.price/me.amount' ],
        #+as      => [ qw/unitprice/ ],
        order_by => { -desc => 'purchaseid' },
        rows     => 5,
    })->get_column('price')->func('AVG');
}

sub conditions {
    my ($self, $cashcard, $quantity) = @_;
    my $parser = schema->storage->datetime_parser;

    # if no conditions have been explicitly defined for this product, there
    # may be a default condition for the group of the user, so we also look
    # for it. however, these conditions have lower priority than product
    # conditions.
    return schema->resultset('Condition')->search({
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
}

# determines the price of the product. in case the product is a composite, the
# price is determined by calculating the sum of the prices for each of the
# composite elements. in case any of the elements prices are undefined, the
# composite product's price cannot be determined and thus too evalutes to undef.
# if a condition has been created for a composite product, the condition will
# be applied to each composite element base and summed up.
sub price {
    my ($self, $cashcard, $quantity) = @_;

    # if no quantity was applied, we assume a qty of 1
    $quantity ||= 1;

    # check if we are a composite product and return the sum if so
    my $composites = $self->composites;
    if ($composites->count) {
        DEBUG 'given product '.$self->product.' is a composite, trying to '
            .'derive price';

        # if there is a condition for this composite product and it is not a
        # fix price, apply it to all elements. if it is a fix price, return it.
        # if there is no condition for this composite, calculate the composite
        # price by summing up the prices of the elements.
        my $cconditions = $self->conditions($cashcard, $quantity);
        if ($cconditions->count) {
            DEBUG 'condition context for composite product '.$self->name.' ('
                .$self->id.') is ['
                .join(",", $cconditions->get_column('id')->all())
                .']';


            if ($cconditions->first->is_fixed) {
                DEBUG 'condition of composite product '.$self->product.' is fixed';
                return $cconditions->first->apply($self)
            }

            # the composite does not have a fix price -> apply condition to
            # elements and sum up their calculated prices
            my $price = 0;
            while (my $p = $composites->next) {
                my $eprice = $cconditions->first->apply($p);
                return undef unless $eprice;
                $price += $eprice;
            }

            DEBUG 'price for composite product '.$self->name.' (id '
                .$self->product.') determined to be '.$price;
            return $price;
        }

        # there is no special condition for this composite; thus, we sum up the
        # individual prices of the elements

        DEBUG 'no special condition for composite product '.$self->name.' ('
            .$self->id.') defined; deriving price recursively';

        my $price = 0;
        while (my $p = $composites->next) {
            my $eprice = $p->price($cashcard, $quantity * $p->units);
            return undef unless $eprice;
            $price += $eprice;
        }

        DEBUG 'price for composite product '.$self->name.' (id '
            .$self->product.') determined to be '.$price;
        return $price;
    }

    # this is an "ordinary" product
    my $conditions = $self->conditions($cashcard, $quantity);
    unless ($conditions->count) {
        ERROR 'could not calculate price for product '.$self->name
            .' ('.$self->id.'); no valid conditions could be found';
        return undef;
    }

    DEBUG 'condition context for '.$self->name.' ('.$self->id.') is ['
        .join(",", $conditions->get_column('id')->all()).']';

    # prices are always rounded up to the tenth digit for moar profit
    my $price = $conditions->first->apply($self);

    DEBUG 'price for elementary product '.$self->name.' (id '
        .$self->product.') determined to be '.$price;
    return $price;
}

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
