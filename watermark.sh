#! /bin/bash


## constants ##
WATERMARK=/home/kakurady/works/2015/watermark_nekotoba2.png
CUSTOM_QTABLE=/home/kakurady/dev/watermark_images/qtbl_Peterson93.txt # optional

CJPEG=/home/kakurady/apps/mozjpeg/bin/cjpeg
COMPOSITE=composite
CONVERT=convert
DSSIM=/home/kakurady/Downloads/dssim/bin/dssim
EXIFTOOL=exiftool
PARALLEL=parallel

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
if [ ! -d resized_87_1x1 ]
then
	mkdir resized_87_1x1
fi
if [ ! -d resized_92_1x1 ]
then
	mkdir resized_92_1x1
fi
if [ ! -d resized_92_212 ]
then
	mkdir resized_92_212
fi
if [ ! -d resized_92_p93 ]
then
	mkdir resized_92_p93
fi
if [ ! -d resized_92_p87 ]
then
	mkdir resized_92_p87
fi

report_ssim() {
    local filename
    filename=${1%.*}
    $DSSIM $@ > "$filename.dssim.txt"
    shift
    wc -c $@ > "$filename.wc.txt"
    cut -f 1 "$filename.dssim.txt" | paste - "$filename.wc.txt" | tee "$filename.report.txt"
    rm "$filename.dssim.txt" "$filename.wc.txt"
}

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
	$COMPOSITE -gravity $gravity -geometry +32+32 "$WATERMARK" "$1" "watermarked/${1%.*}_watermarked.tga"
	$CJPEG -quality 70 -quant-table 2 -targa -outfile "watermarked/${1%.*}_large.jpg" "watermarked/${1%.*}_watermarked.tga"
	
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
	$CONVERT "watermarked/${1%.*}_watermarked.tga" -gamma .45455 -resize 1200x960 -gamma 2.2 "resized/${1%.*}_resized.tga"
	rm "watermarked/${1%.*}_watermarked.tga"
	$CJPEG -quant-table 2 -quality 92.5 -targa -outfile "resized/${1%.*}_medium.jpg" "resized/${1%.*}_resized.tga"
	
	#test subsampling modes
	$CJPEG -quant-table 2 -quality 87 -sample 1x1 -targa -outfile "resized_87_1x1/${1%.*}_1.jpg" "resized/${1%.*}_resized.tga"
	$CJPEG -quant-table 2 -quality 92.5 -sample 2x2,1x1,2x2 -targa -outfile "resized_92_212/${1%.*}_2.jpg" "resized/${1%.*}_resized.tga"
	if [ ! -f "$CUSTOM_QTABLE" ]
	then
		$CJPEG -quality 90 -qtables "$CUSTOM_QTABLE" -qslots 0,1,2 -sample 1x1 -targa -outfile "resized_92_p93/${1%.*}_p.jpg" "resized/${1%.*}_resized.tga"
		$CJPEG -quality 87 -qtables "$CUSTOM_QTABLE" -qslots 0,1,2 -sample 1x1 -targa -outfile "resized_92_p87/${1%.*}_q.jpg" "resized/${1%.*}_resized.tga"
	fi
    	
    convert "resized/${1%.*}_resized.tga" "resized/${1%.*}_resized.png" 
    report_ssim "resized/${1%.*}_resized.png" "resized/${1%.*}_medium.jpg" "resized_87_1x1/${1%.*}_1.jpg" "resized_92_212/${1%.*}_2.jpg" "resized_92_p93/${1%.*}_p.jpg" "resized_92_p87/${1%.*}_q.jpg"
	rm "resized/${1%.*}_resized.tga" "resized/${1%.*}_resized.png"
	
	#add exif tags
	#
	#May need to add color space if not sRGB. However, that bloats image
	$EXIFTOOL -tagsFromFile "$1" --Olympus:all --Nikon:all -overwrite_original "${1%.*}.jpg" "resized/${1%.*}_medium.jpg" "watermarked/${1%.*}_large.jpg" "resized_87_1x1/${1%.*}_1.jpg"  "resized_92_212/${1%.*}_2.jpg" "resized_92_p93/${1%.*}_p.jpg" "resized_92_p87/${1%.*}_q.jpg"
	
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
export -f report_ssim
export -f doIt
export CJPEG
export COMPOSITE
export CONVERT
export DSSIM
export EXIFTOOL
export CUSTOM_QTABLE
export WATERMARK
export keep_original
export gravity

$PARALLEL --bar doIt ::: "$@"
cat resized/*.report.txt >> resized/report_summary.txt
rm resized/*.report.txt
