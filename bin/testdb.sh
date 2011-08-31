#!/bin/bash

curl -D - -X POST -H 'Content-Type: application/json' -d '{"name":"Club Mate Cola","ean":"1333337"}' http://localhost:3000/products
curl -D - -X POST -H 'Content-Type: application/json' -d '{"supplier": "Loscher", "purchasedate":"31-02-2011","amount":"12","price":"1.00"}' http://localhost:3000/products/1333337/purchases
curl -D - -X POST -H 'Content-Type: application/json' -d '{"name":"Mitglieder"}' http://localhost:3000/groups
curl -D - -X POST -H 'Content-Type: application/json' -d '{"groupid":1,"userid":1}' http://localhost:3000/groups/1/memberships
curl -D - -X POST -H "Content-Type: application/json" -d '{"code":"foobar1","userid":1,"groupid":1}' http://localhost:3000/cashcards
curl -D - -X POST -H 'Content-Type: application/json' -d '{"groupid":1,"userid":1,"premium":0.2,"fixedprice":0.30,"comment":"foooi"}' http://localhost:3000/products/1333337/conditions
curl -D - -X POST -H 'Content-Type: application/json' -d '{"groupid":1,"userid":0,"premium":0.6,"comment":"foooi"}' http://localhost:3000/products/1333337/conditions
curl -D - -X POST -H "Content-Type: application/json" -d '{"code":"foobar3","userid":1,"groupid":1}' http://localhost:3000/cashcards
curl -D - -X POST -H "Content-Type: application/json" -d '{"code":"gast1","userid":0,"groupid":1}' http://localhost:3000/cashcards
