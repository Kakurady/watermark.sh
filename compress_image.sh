#! /bin/bash

if [ ! -d watermarked ] 
then
	mkdir watermarked
fi
if [ ! -d resized ] 
then
	mkdir resized
fi
for f in *.tif
do
	echo "working on $f"
	#convert full-sized image
	convert $f "${f%.*}.tga"
	~/Downloads/mozjpeg/build/cjpeg -quality 90 -targa -outfile "${f%.*}.jpg" "${f%.*}.tga"
	#rm "${f%.*}.tga" 
	
	#composite watermarked image
	#composite -gravity southeast -geometry +32+32 /media/kakurady/Seagate\ Backup\ Plus\ Drive/works/2015/watermark_nekotoba2.png "$f" "${f%.*}.tga"
	~/Downloads/mozjpeg/build/cjpeg -quality 70 -targa -outfile "watermarked/${f%.*}.jpg" "${f%.*}.tga" 
	
	#shrink down watermarked image
	convert "${f%.*}.tga" -gamma .45455 -resize 960x720 -gamma 2.2 "resized/${f%.*}.tga" 
	rm "${f%.*}.tga"
	~/Downloads/mozjpeg/build/cjpeg -quality 85 -targa -outfile "resized/${f%.*}.jpg" "resized/${f%.*}.tga" 
	rm "resized/${f%.*}.tga"
	
	#add exif tags
	exiftool -tagsFromFile "$f" -overwrite_original "${f%.*}.jpg" "resized/${f%.*}.jpg" "watermarked/${f%.*}.jpg"
	mv "$f.out.pp3" "${f%.*}.jpg.out.pp3"
	rm $f
done
