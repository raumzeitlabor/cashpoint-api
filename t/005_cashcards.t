use Test::More tests => 26;

use strict;
use warnings;

use Cashpoint::API;
use Dancer::Test;
use Test::JSON;

use Dancer::Plugin::DBIC;
use DateTime;
use JSON;

use Data::Dumper;

use Cashpoint::Utils qw/generate_token/;

my $token = $ENV{AUTH_TOKEN};
my $userid = 24;

ok defined $token, "AUTH_TOKEN is set";

# check if auth is correct
my $response = dancer_response GET => '/auth', {
    params => { auth_token => $token, }
};

print Dumper $response->{content};
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
my $code = substr(generate_token, 0, 18);

# create a new cashcard
$response = dancer_response POST => '/cashcards', {
    params => {
        auth_token => $token,
        user => $userid,
        group => $groupid,
        code => $code,
    },
};

is $response->{status}, 201, "created new cashcard";

# check if cashcard is correctly announced
$response = dancer_response GET => '/cashcards', {
    params => {
        auth_token => $token,
    },
};

is $response->{status}, 200, "response for GET /cashcards is 200";
is_valid_json $response->{content}, "response for GET /cashcards is valid json";

my @found = grep {
    $_->{code} eq $code && $_->{user}->{id} == $userid
        && $_->{group}->{id} == $groupid
} @{from_json($response->content)};

is length @found, 1, "created cashcard exists";

# disable and enable cashcard
$response = dancer_response PUT => '/cashcards/'.$code.'/disable', {
    params => {
        auth_token => $token,
    },
};

is $response->{status}, 200, "response for PUT /cashcards/$code/disable is 200";

$response = dancer_response GET => '/cashcards', {
    params => {
        auth_token => $token,
    },
};

@found = grep {
    $_->{code} eq $code && $_->{user}->{id} == $userid
        && $_->{group}->{id} == $groupid && $_->{disabled} == 1
} @{from_json($response->content)};

is length @found, 1, "cashcard disabled";

$response = dancer_response PUT => '/cashcards/'.$code.'/enable', {
    params => {
        auth_token => $token,
    },
};

is $response->{status}, 200, "response for PUT /cashcards/$code/enable is 200";

$response = dancer_response GET => '/cashcards', {
    params => {
        auth_token => $token,
    },
};

@found = grep {
    $_->{code} eq $code && $_->{user}->{id} == $userid
        && $_->{group}->{id} == $groupid && $_->{disabled} == 0
} @{from_json($response->content)};

is length @found, 1, "cashcard enabled";

# check credit before charge
$response = dancer_response GET => "/cashcards/$code/credits", {
    params => {
        auth_token => $token,
    },
};

is $response->{status}, 200, "response for GET /cashcards/$code/credits is 200";
is_valid_json $response->{content}, "response for GET /cashcards/$code/credits is valid json";

my $balance = from_json($response->{content})->{balance};

# charge some credit on cashcard
$response = dancer_response POST => "/cashcards/$code/credits", {
    params => {
        auth_token => $token,
        type => 1, # charge
        amount => 10,
    },
};

is $response->{status}, 201, "response for POST /cashcards/$code/credits is 201";

# check credit after charge
$response = dancer_response GET => "/cashcards/$code/credits", {
    params => {
        auth_token => $token,
    },
};

is $response->{status}, 200, "response for GET /cashcards/$code/credits is 200";
is_valid_json $response->{content}, "response for GET /cashcards/$code/credits is valid json";
is from_json($response->{content})->{balance}, $balance+10, "successfully charged amount";

# create second cashcard for transfering credits to it
my $secondcode = substr(generate_token, 0, 18);
$response = dancer_response POST => '/cashcards', {
    params => {
        auth_token => $token,
        user => $userid,
        group => $groupid,
        code => $secondcode,
    },
};

# unlock the card for credit transfer
$response = dancer_response PUT => "/cashcards/$code/unlock", {
    params => {
        auth_token => $token,
        pin => 182391,
    }
};

is $response->{status}, 200, "response for PUT /cashcards/$code/unlock is 200";

# transfer some credits to the new one
$response = dancer_response POST => "/cashcards/$code/transfers", {
    params => {
        auth_token => $token,
        recipient => $secondcode,
        amount => 5,
        reason => "hello world",
    },
};

is $response->{status}, 201, "response for POST /cashcards/$code/transfer is 201";
