#! /bin/bash

JPEGTRAN=/home/kakurady/apps/mozjpeg/bin/jpegtran
preserve_existing_file="yes"

USAGE_CMDLINE="Usage: $0 [-c] files ..."

USAGE="$USAGE_CMDLINE
    -c      clobber (i.e. overwrite) existing file
"

while getopts c option_name
do
    case $option_name in
    c)      preserve_existing_file="";;
    \?)     echo "$USAGE"; exit 1;;
    esac
done
shift $(($OPTIND - 1))

doIt() {
    outfile="${1%.*}_o.jpg"
    if [ "$preserve_existing_file" -a -f "$outfile" ]
    then
        #file already exists
        echo "$outfile already exists. Skipping $1"
	    exit 1
    fi

    # this will keep color space info. Will also keep thumbnails.
    $JPEGTRAN -copy all -outfile "$outfile" "$1"
}

for f in $@; do doIt $f; done
