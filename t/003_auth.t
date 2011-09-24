use Test::More tests => 30;

use strict;
use warnings;

# the order is important
use Cashpoint::API;
use Dancer::Test;
use JSON;

my $response;

# baskets
response_status_is[POST   => '/baskets'], 401,            'POST   /baskets response is 401';
response_status_is[GET    => '/baskets/1'], 401,          'GET    /baskets/:id response is 401';
response_status_is[DELETE => '/baskets/1'], 401,          'DELETE /baskets/:id response is 401';
response_status_is[GET    => '/baskets/1/items'], 401,    'GET    /baskets/:id/items response is 401';
response_status_is[POST   => '/baskets/1/items'], 401,    'POST   /baskets/:id/items response is 401';
response_status_is[DELETE => '/baskets/1/items/1'], 401,  'DELETE /baskets/:id/items/:id response is 401';
response_status_is[PUT    => '/baskets/1/checkout'], 401, 'PUT    /baskets/:id/checkout response is 401';

# groups
response_status_is[GET    => '/groups'], 401,                 'GET    /groups response is 401';
response_status_is[POST   => '/groups'], 401,                 'POST   /groups response is 401';
response_status_is[DELETE => '/groups/1'], 401,               'DELETE /groups/:id response is 401';
response_status_is[GET    => '/groups/1/memberships'], 401,   'GET    /groups/:id/memberships response is 401';
response_status_is[POST   => '/groups/1/memberships'], 401,   'POST   /groups:id/memberships response is 401';
response_status_is[DELETE => '/groups/1/memberships/1'], 401, 'DELETE /groups/:id/memberships/:id response is 401';

# cashcards
response_status_is[GET    => '/cashcards'], 401,                            'GET    /cashcards response is 401';
response_status_is[POST   => '/cashcards'], 401,                            'POST   /cashcards response is 401';
response_status_is[PUT    => '/cashcards/abcdefghijklmnopqr/enable'], 401,  'PUT    /cashcards/:code/enable response is 401';
response_status_is[PUT    => '/cashcards/abcdefghijklmnopqr/disable'], 401, 'PUT    /cashcards/:code/disable response is 401';
response_status_is[GET    => '/cashcards/abcdefghijklmnopqr/credits'], 401, 'GET    /cashcards/:code/credits response is 401';
response_status_is[POST   => '/cashcards/abcdefghijklmnopqr/credits'], 401, 'POST   /cashcards/:code/credits response is 401';
response_status_is[PUT    => '/cashcards/abcdefghijklmnopqr/unlock'], 401,  'PUT    /cashcards/:code/unlock response is 401';

# products
response_status_is[GET    => '/products'], 401, 'GET    /products response is 401';
response_status_is[POST   => '/products'], 401, 'POST   /products response is 401';
response_status_is[GET    => '/products/42186700'], 401, 'GET    /products/:ean response is 401';
response_status_is[GET    => '/products/42186700/price'], 401, 'GET    /products/:ean/price response is 401';
response_status_is[GET    => '/products/42186700/conditions'], 401, 'GET    /products/:ean/conditions response is 401';

# purchases
response_status_is[GET    => '/products/42186700/purchases'],   401, 'GET    /products/:ean/purchases response is 401';
response_status_is[POST   => '/products/42186700/purchases'],   401, 'POST   /products/:ean/purchases response is 401';
response_status_is[DELETE => '/products/42186700/purchases/1'], 401, 'DELETE /products/:ean/purchases response is 401';

# auth
response_status_is[POST   => '/auth'], 400, 'POST   /auth response is 400';
response_status_is[DELETE => '/auth'], 401, 'DELETE /auth response is 401';

