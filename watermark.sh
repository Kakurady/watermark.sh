#! /bin/bash


## constants ##
WATERMARK=/home/kakurady/works/2017/kakurady_lettering_watermark.png
#CUSTOM_QTABLE=/home/kakurady/dev/watermark_images/qtbl_Peterson93.txt # optional

CJPEG=/home/kakurady/apps/mozjpeg/bin/cjpeg
COMPOSITE=composite
CONVERT=convert
DSSIM=/home/kakurady/Downloads/dssim/bin/dssim
EXIFTOOL=exiftool
PARALLEL=parallel
parallel_params="--bar --ungroup --load 95%"

USAGE_CMDLINE="Usage: $0 [-gwks] files ..."

USAGE="$USAGE_CMDLINE
    -g      set gravity
    -w      skip watermarking
    -k      keep original file
    -s      report DSSIM
"

## variables ##
keep_original=""
report_dssim=""
gravity="southeast"
do_watermark="y"

while getopts g:wks option_name
do
    case $option_name in
    g)      gravity=$OPTARG;;
    k)      keep_original="y";;
    s)      report_dssim="y";;
    w)      do_watermark="";;
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
    local watermarked_image
	echo "working on $1"
	
	
	#convert full-sized image
	#
	# this is an "archival" quality image suitable for printing
	# saved at an arbitrary 95 quality factor
	#
	# Using PNG as intermediate format to preserve color space info
	# PNG "quality" 3 means Huffman only, "average" filtering 
	# ( https://www.imagemagick.org/script/command-line-options.php#quality )
	$CONVERT -quality 3 "$1" "${1%.*}.png"
	$CJPEG -quant-table 2 -quality 95 -outfile "${1%.*}.jpg" "${1%.*}.png"

	
	#composite watermarked image
	#
	# this image is uploaded to Flickr / Weasyl, which will scale it down
	# also suitable for display on a 2x1080p / UHD display
	# JPEG quality factor 70 here is arbitrary
	#
	# since the display is a lot denser you can get away with throwing away details ("compressive image"). (however, you can't compare quality factors between encoders with different quantization tables; comparing subjective quality at a given file size is more reasonable [JPEG files don't actually have a quality factor; you're scaling a 64-entry table on how accurately details are stored in a 8x8 block])
	if [ "$do_watermark" ]
	then
	    watermarked_image="watermarked/${1%.*}_watermarked.png"
    	$COMPOSITE -gravity $gravity -geometry +4+4 -quality 3 "$WATERMARK" "${1%.*}.png" "$watermarked_image"
    	rm "${1%.*}.png"
	else
	    watermarked_image="${1%.*}.png"
	fi

	$CJPEG -quality 70 -quant-table 2 -outfile "watermarked/${1%.*}_large.jpg" "$watermarked_image"
	
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
	$CONVERT "$watermarked_image" -gamma .45455 -resize 1200x960 -gamma 2.2 -quality 3 "resized/${1%.*}_resized.png"
	rm "$watermarked_image"
	$CJPEG -quant-table 2 -quality 92.5 -outfile "resized/${1%.*}_medium.jpg" "resized/${1%.*}_resized.png"
	
	#test subsampling modes
	#$CJPEG -quant-table 2 -quality 87 -sample 1x1 -outfile "resized_87_1x1/${1%.*}_1.jpg" "resized/${1%.*}_resized.png"
	#$CJPEG -quant-table 2 -quality 92.5 -sample 2x2,1x1,2x2 -outfile "resized_92_212/${1%.*}_2.jpg" "resized/${1%.*}_resized.png"
	if [ -f "$CUSTOM_QTABLE" ]
	then
		$CJPEG -quality 90 -qtables "$CUSTOM_QTABLE" -qslots 0,1,2 -sample 1x1 -outfile "resized_92_p93/${1%.*}_p.jpg" "resized/${1%.*}_resized.png"
		$CJPEG -quality 87 -qtables "$CUSTOM_QTABLE" -qslots 0,1,2 -sample 1x1 -outfile "resized_92_p87/${1%.*}_q.jpg" "resized/${1%.*}_resized.png"
	fi
    	
    #convert "resized/${1%.*}_resized.png" "resized/${1%.*}_resized.png"
    if [ "$report_dssim" -a -f "$DSSIM" ]
    then
        report_ssim "resized/${1%.*}_resized.png" "resized/${1%.*}_medium.jpg" "resized_87_1x1/${1%.*}_1.jpg" "resized_92_212/${1%.*}_2.jpg" "resized_92_p93/${1%.*}_p.jpg" "resized_92_p87/${1%.*}_q.jpg"
    fi

	rm "resized/${1%.*}_resized.png" #"resized/${1%.*}_resized.png"
	
	#add exif tags
	#
	#May need to add color space if not sRGB. However, that bloats image (by 6kb)
	#if only we could insert the PNG built-in sRGB chunk from RawTherapee?
	$EXIFTOOL \
	-use MWG \
	-tagsFromFile "$1" \
	-icc_profile \
	-all \
	-exif:serialnumber= -exif:lensserialnumber= \
	-MakerNotes:all= \
	-overwrite_original \
	-z \
	"${1%.*}.jpg" "resized/${1%.*}_medium.jpg" "watermarked/${1%.*}_large.jpg"
	# "resized_87_1x1/${1%.*}_1.jpg"  "resized_92_212/${1%.*}_2.jpg" "resized_92_p93/${1%.*}_p.jpg" "resized_92_p87/${1%.*}_q.jpg"
	
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
export do_watermark

$PARALLEL $parallel_params doIt ::: "$@"
cat resized/*.report.txt >> resized/report_summary.txt
rm resized/*.report.txt
