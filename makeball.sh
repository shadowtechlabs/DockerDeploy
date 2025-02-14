#!/bin/bash

# check to see if the tar exists - if not, make a new one.
if [ ! -f shok.tar ]; then
    tar --exclude={"installer.sh","makeball.sh","shok.tar"} -cf shok.tar .
else
    tar --exclude={"installer.sh","makeball.sh","shok.tar"} -uf shok.tar .
fi