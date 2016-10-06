#! /bin/bash


USAGE_CMDLINE="Usage: $0 [-k] files ..."

USAGE="$USAGE_CMDLINE
    -k      keep original file
"
#variables
keep_original=""

while getopts k f
do
    case $f in
    k)      keep_original="y";;
    \?)     echo "$USAGE"; exit 1;;
    esac
done
shift $(($OPTIND - 1))

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

doIt() {
    original_is_jpg=""
    if [ -f "${1%.*}.jpg" ]
    then
        original_is_jpg="y"
    fi

	echo "working on $1"
	#convert full-sized image
	convert $1 "${1%.*}.tga"
	if [ ! "$original_is_jpg" ]
	then
    	~/Downloads/mozjpeg/build/cjpeg -quality 90 -targa -outfile "${1%.*}.jpg" "${1%.*}.tga"
	fi
	#rm "${1%.*}.tga" 
	
	#composite watermarked image
	#composite -gravity southeast -geometry +32+32 /media/kakurady/Seagate\ Backup\ Plus\ Drive/works/2015/watermark_nekotoba2.png "$1" "${1%.*}.tga"
	~/Downloads/mozjpeg/build/cjpeg -quality 70 -targa -outfile "watermarked/${1%.*}.jpg" "${1%.*}.tga" 
	
	#shrink down watermarked image
	convert "${1%.*}.tga" -gamma .45455 -resize 960x720 -gamma 2.2 "resized/${1%.*}.tga" 
	rm "${1%.*}.tga"
	~/Downloads/mozjpeg/build/cjpeg -quality 85 -targa -outfile "resized/${1%.*}.jpg" "resized/${1%.*}.tga" 
	rm "resized/${1%.*}.tga"
	
	#add exif tags
	if [ "$original_is_jpg" ]
	then
        exiftool -tagsFromFile "$1" -overwrite_original "resized/${1%.*}.jpg" "watermarked/${1%.*}.jpg"
	else 
    	exiftool -tagsFromFile "$1" -overwrite_original "${1%.*}.jpg" "resized/${1%.*}.jpg" "watermarked/${1%.*}.jpg"
	fi

	mv "$1.out.pp3" "${1%.*}.jpg.out.pp3"
    if [ ! "$keep_original" -o "$original_is_jpg" ]
    then
    	rm $1
    else 
        true
        #echo "keep original"
	fi
}

#for f in *.tif; do doIt $f; done
export -f doIt
export keep_original
#export WATERMARK
parallel --bar doIt ::: "$@"
