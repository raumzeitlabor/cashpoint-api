use Test::More tests => 20;

use strict;
use warnings;

use Cashpoint::API;
use Dancer::Test;
use Test::JSON;

use Dancer::Plugin::DBIC;
use DateTime;
use JSON;

my $token = $ENV{AUTH_TOKEN};

ok defined $token, "AUTH_TOKEN is set";

# check if auth is correct
my $response = dancer_response GET => '/auth', {
    params => { auth_token => $token, }
};

is $response->{status}, 200, "successfully authorized";

# create a new group
$response = dancer_response POST => '/groups', {
    params => {
        auth_token => $token,
        name       => "foobar",
    },
};

is $response->{status}, 201, "created group \"foobar\"";
is_valid_json $response->content, "got json response";

my $groupid = from_json($response->content)->{id};

# check if groups are correctly announced
$response = dancer_response GET => '/groups', {
    params => { auth_token => $token, },
};

is $response->{status}, 200, "response for GET /groups is 200";
is_valid_json $response->content, "response for GET /groups is valid json";

my @found = grep { $_->{group} == $groupid && $_{name} == "foobar" } @{from_json($response->content)};
is length @found, 1, "created group exists";

# create memberships
$response = dancer_response POST => "/groups/$groupid/memberships", {
    params => {
        auth_token => $token,
        user       => 24,
    },
};

is $response->{status}, 201, "created membership of user $_ to group \"foobar $groupid\"";
is_valid_json $response->content, "got json response";

# check if memberships have been set correctly
$response = dancer_response GET => "/groups/$groupid/memberships", {
    params => { auth_token => $token },
};

is $response->{status}, 200, "response for GET /groups/$groupid/memberships is 200";
is_valid_json $response->content, "response for GET /groups/$groupid/memberships is valid json";
is @{from_json $response->content}, 1, "number of memberships is correct";

$response = dancer_response DELETE => "/groups/$groupid", {
    params => { auth_token => $token }
};
is $response->{status}, 200, "group \"foobar\" successfully deleted";

# check if groups are really deleted
$response = dancer_response GET => "/groups/$groupid/memberships", {
    params => { auth_token => $token },
};

is $response->{status}, 404, "response for GET /groups/$groupid/memberships is 404";

# create the group again and check if memberships are deleted
$response = dancer_response POST => '/groups', {
    params => {
        auth_token => $token,
        name       => "foobar",
    },
};

is $response->{status}, 201, "created group \"foobar\"";
is_valid_json $response->content, "got json response";
is $groupid, from_json($response->content)->{id}, "got the same groupid again";

$response = dancer_response GET => "/groups/$groupid/memberships", {
    params => { auth_token => $token },
};

is $response->{status}, 200, "response for GET /groups/$groupid/memberships is 200";
is_valid_json $response->content, "response for GET /groups/$groupid/memberships is valid json";
is_json $response->content, to_json([]), "group does not have any memberships set";
