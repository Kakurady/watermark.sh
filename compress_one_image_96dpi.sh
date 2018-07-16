#! /bin/bash
CJPEG=/home/kakurady/apps/mozjpeg/bin/cjpeg
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

$CJPEG -quality "$quality" -outfile "${1%.*}.jpg" "$1" 
