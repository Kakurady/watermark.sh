#! /bin/bash
quality=94
USAGE="
Usage: $0 [-q] file
"

while getopts q: f
do
case $f in
(q) quality=$OPTARG;;
\?) echo $USAGE; exit 1;;
esac
done
shift `expr $OPTIND - 1`

~/Downloads/mozjpeg/build/cjpeg -quality "$quality" -outfile "${1%.*}.jpg" "$1" 
