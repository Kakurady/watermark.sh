#! /bin/bash


## constants ##
WATERMARK=/home/kakurady/works/2015/watermark_nekotoba2.png

CJPEG=/home/kakurady/apps/mozjpeg/bin/cjpeg
COMPOSITE=composite
CONVERT=convert
EXIFTOOL=exiftool

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
	#
	# this is an "archival" quality image suitable for printing
	# saved at an arbitrary 95 quality factor
	$CONVERT "$1" "${1%.*}.tga"
	$CJPEG -quant-table 2 -quality 95 -targa -outfile "${1%.*}.jpg" "${1%.*}.tga"
	rm "${1%.*}.tga" 
	
	#composite watermarked image
	#
	# this image is uploaded to Flickr / Weasyl, which will scale it down
	# also suitable for display on a 2x1080p / UHD display
	# quality factor 70 here is arbitrary
	#
	# since the display is a lot denser you can get away with throwing away details ("compressive image"). (however, you can't compare quality factors between encoders with different quantization tables; comparing subjective quality at a given file size is more reasonable [JPEG files don't actually have a quality factor; you're scaling a 64-entry table on how accurately details are stored in a 8x8 block])
	$COMPOSITE -gravity $gravity -geometry +32+32 "$WATERMARK" "$1" "${1%.*}_watermarked.tga"
	$CJPEG -quality 70 -quant-table 2 -targa -outfile "watermarked/${1%.*}.jpg" "${1%.*}_watermarked.tga" 
	
	# shrink down watermarked image
	#
	# this image is specifically for Fur Affinity (and some other chat apps
	# that will refuse dimensions > 4096)
	#
	# quality factor 92.5 here.
	# 85 was too low, problems on e.g. Buster Bunny's fur
	# 95 would use as much as 40% more data than 92.5 and 100% more than 85
	# 91.25 would probably suffice (saves 5% over 92.5)
	# but I can't tell differences after looking at too many photos
	# quant table 2 was personal pref; no discernable difference from
	# table 0 at the same quality factor
	$CONVERT "${1%.*}_watermarked.tga" -gamma .45455 -resize 1200x960 -gamma 2.2 "resized/${1%.*}_resized.tga" 
	rm "${1%.*}_watermarked.tga"
	$CJPEG -quant-table 2 -quality 92.5 -targa -baseline -outfile "resized/${1%.*}.jpg" "resized/${1%.*}_resized.tga" 
	rm "resized/${1%.*}_resized.tga"
	
	#add exif tags
	#
	#May need to add color space if not sRGB. However, that bloats image
	$EXIFTOOL -tagsFromFile "$1" --Olympus:all --Nikon:all -overwrite_original "${1%.*}.jpg" "resized/${1%.*}.jpg" "watermarked/${1%.*}.jpg"
	
	#move RawTherapee sidecar file, if one exist
	if [ -f "$1.out.pp3" ]
	then
    	mv "$1.out.pp3" "${1%.*}.jpg.out.pp3"
    fi
    
    # delete the original file
    if [ ! "$keep_original" ]
    then
    	rm $1
    else 
        true
	fi
}

#for f in *.tif; do doIt $f; done
export -f doIt
export CJPEG
export COMPOSITE
export CONVERT
export EXIFTOOL
export WATERMARK
export keep_original
export gravity

parallel --bar doIt ::: "$@"
