#! /bin/sh -x

if [ -d test ]
then
  rm -rf test
fi
mkdir -p test
cp ../prototype/run.sh test
cd test
./run.sh
