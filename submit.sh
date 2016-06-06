#!/bin/sh
zip -r await.zip src haxelib.json README.md -x "*/\.*"
haxelib submit await.zip
rm await.zip 2> /dev/null