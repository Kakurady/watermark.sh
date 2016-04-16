#! /bin/bash

~/Downloads/mozjpeg/build/cjpeg -quality 94 -outfile "${1%.*}.jpg" "$1" 
