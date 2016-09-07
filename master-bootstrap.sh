#!/bin/bash

TAG="0.10.1";

DIR=".vapor-toolbox-$TAG";

rm -rf $DIR;

mkdir -p $DIR
cd $DIR;

echo "Downloading...";
git clone https://github.com/vapor/toolbox vapor-toolbox > /dev/null 2>&1;
cd vapor-toolbox;
git checkout $TAG > /dev/null 2>&1;

echo "Compiling...";
swift build -c release > /dev/null;

echo "Installing...";
.build/release/Executable self install;

cd ../../;
rm -rf $DIR;

echo 'Use vapor --help and vapor <command> --help to learn more.';
