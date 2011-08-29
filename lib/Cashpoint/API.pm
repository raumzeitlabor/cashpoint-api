package Cashpoint::API;
use Dancer ':syntax';
use Cashpoint::API::Products;
use Cashpoint::API::Purchases;

our $VERSION = '0.1';

set serializer => 'JSON';

true;
