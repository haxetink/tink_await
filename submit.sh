#!/bin/sh
zip -r await.zip await haxelib.json README.md -x "*/\.*"
haxelib submit await.zip
rm await.zip 2> /dev/null