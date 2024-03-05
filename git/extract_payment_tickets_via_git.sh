#!/bin/bash


OLD_PROD=a05faaf46d6e5c2f039fa29a6ba2d639e2f24b0a
NEW_PROD=22e3b870be90d87f05376a351358f2e4804be120

cd ~/work/kingmakers-frontend/

git log --grep='PAY-' $OLD_PROD..$NEW_PROD --pretty=format:"%B" | grep -o 'PAY-\d\d\d\d' | sort | uniq

