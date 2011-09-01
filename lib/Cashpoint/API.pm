package Cashpoint::API;
use Dancer ':syntax';

use Cashpoint::API::Groups;
use Cashpoint::API::Baskets;
use Cashpoint::API::Products;
use Cashpoint::API::Purchases;
use Cashpoint::API::Cashcards;

our $VERSION = '0.1';

set serializer => 'JSON';

true;
