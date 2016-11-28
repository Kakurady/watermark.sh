#! /bin/bash


## constants ##
WATERMARK=/home/kakurady/works/2015/watermark_nekotoba2.png

USAGE_CMDLINE="Usage: $0 [-gk] files ..."

USAGE="$USAGE_CMDLINE
    -g      set gravity
    -k      keep original file
"

## variables ##
keep_original=""
gravity="southeast"

while getopts g:k f
do
    case $f in
    g)      gravity=$OPTARG;;
    k)      keep_original="y";;
    \?)     echo "$USAGE"; exit 1;;
    esac
done
shift $(($OPTIND - 1))

if [ ! -f "$WATERMARK" ]
then 
	echo "watermark image ($WATERMARK) not found, exiting."
	
	exit 1
fi

if [ $# -lt 1 ]
then
    echo "$USAGE"
    exit 1
fi

if [ ! -d watermarked ] 
then
	mkdir watermarked
fi
if [ ! -d resized ] 
then
	mkdir resized
fi

# Remember to export variables for parallel
doIt() {
	echo "working on $1"
	#convert full-sized image
	convert "$1" "${1%.*}.tga"
	~/Downloads/mozjpeg/build/cjpeg -quality 92 -targa -outfile "${1%.*}.jpg" "${1%.*}.tga"
	rm "${1%.*}.tga" 
	
	#composite watermarked image
	composite -gravity $gravity -geometry +32+32 "$WATERMARK" "$1" "${1%.*}_watermarked.tga"
	~/Downloads/mozjpeg/build/cjpeg -quality 70 -targa -outfile "watermarked/${1%.*}.jpg" "${1%.*}_watermarked.tga" 
	
	#shrink down watermarked image
	convert "${1%.*}_watermarked.tga" -gamma .45455 -resize 960x720 -gamma 2.2 "resized/${1%.*}_resized.tga" 
	rm "${1%.*}_watermarked.tga"
	~/Downloads/mozjpeg/build/cjpeg -quality 85 -targa -outfile "resized/${1%.*}.jpg" "resized/${1%.*}_resized.tga" 
	rm "resized/${1%.*}_resized.tga"
	
	#add exif tags
	exiftool -tagsFromFile "$1" -overwrite_original "${1%.*}.jpg" "resized/${1%.*}.jpg" "watermarked/${1%.*}.jpg"
	if [ -f "$1.out.pp3" ]
	then
    	mv "$1.out.pp3" "${1%.*}.jpg.out.pp3"
    fi
    if [ ! "$keep_original" ]
    then
    	rm $1
    else 
        true
        #echo "keep original"
	fi
}

#for f in *.tif; do doIt $f; done
export -f doIt
export WATERMARK
export keep_original
export gravity
parallel --bar doIt ::: "$@"
