#! /bin/bash

WATERMARK=/home/kakurady/works/2015/watermark_nekotoba2.png

if [ ! -f "$WATERMARK" ]
then 
	echo "watermark image not found, exiting"
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
	echo "working on $1"
	#convert full-sized image
	convert $1 "${1%.*}.tga"
	~/Downloads/mozjpeg/build/cjpeg -quality 90 -targa -outfile "${1%.*}.jpg" "${1%.*}.tga"
	rm "${1%.*}.tga" 
	
	#composite watermarked image
	composite -gravity southeast -geometry +32+32 "$WATERMARK" "$1" "${1%.*}_watermarked.tga"
	~/Downloads/mozjpeg/build/cjpeg -quality 70 -targa -outfile "watermarked/${1%.*}.jpg" "${1%.*}_watermarked.tga" 
	
	#shrink down watermarked image
	convert "${1%.*}_watermarked.tga" -gamma .45455 -resize 960x720 -gamma 2.2 "resized/${1%.*}_resized.tga" 
	rm "${1%.*}_watermarked.tga"
	~/Downloads/mozjpeg/build/cjpeg -quality 85 -targa -outfile "resized/${1%.*}.jpg" "resized/${1%.*}_resized.tga" 
	rm "resized/${1%.*}_resized.tga"
	
	#add exif tags
	exiftool -tagsFromFile "$1" -overwrite_original "${1%.*}.jpg" "resized/${1%.*}.jpg" "watermarked/${1%.*}.jpg"
	mv "$1.out.pp3" "${1%.*}.jpg.out.pp3"
	rm $1
}

for f in *.tif
do
	doIt $f
done
