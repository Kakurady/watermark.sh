#! /bin/bash
CJPEG=/home/kakurady/apps/mozjpeg/bin/cjpeg

convert "$1" -gamma .45455 -resize 960x720 -gamma 2.2 "resized/${1%.*}.tga" 
$CJPEG -quality 90 -targa -outfile "resized/${1%.*}.jpg" "resized/${1%.*}.tga" 
exiftool -tagsFromFile "$1" -overwrite_original -z "resized/${1%.*}.jpg"
