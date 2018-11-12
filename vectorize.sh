#!/usr/bin/env bash

# Dependencies:
#  - imagemagick
#  - potrace

# History:

# # Create ppm images, one per pdf page.
# pdfimages $1.pdf $1_conv_temp
# # Create pbm images, no grey levels (black and white only), from the ppm.
# mkbitmap $1_conv_temp*.ppm -t 0.48
# # Create pdf files from the pbm images, one per original page.
# potrace -b pdf -r 150 $1_conv_temp*.pbm
# # Combine the several pdf files into one.
# gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=$1_vect.pdf $1_conv_temp*.pdf
# 
# # Clean up
# rm $1_conv*

echo "### THIS SCRIPT"
this_script=$(basename "$0")

echo "### DEPENDENCIES"

# Check dependencies
type pdfimages > /dev/null 2>&1 || { echo >&2 "Missing dependency, install pdfimages!" ; exit 1 ; }
type convert > /dev/null 2>&1 || { echo >&2 "Missing dependency, install convert!" ; exit 1 ; }
type mkbitmap > /dev/null 2>&1 || { echo >&2 "Missing dependency, install mkbitmap!" ; exit 1 ; }
type potrace > /dev/null 2>&1 || { echo >&2 "Missing dependency, install potrace!" ; exit 1 ; }
type gs > /dev/null 2>&1 || { echo >&2 "Missing dependency, install gs!" ; exit 1 ; }

echo "### DISPLAY USAGE DEFINITION"
display_usage() {
    echo "$this_script [options] <input_file(s)>"
    echo
    echo "This script takes image input and makes it black and white."
    echo
    echo "  OPTIONS:"
    echo "    -h --help        This help."
    echo "    -s --separate    Do not combine the generated images to a single pdf file."
    echo "    -f --format      Output format. Anything other than pdf implies -s."
    echo "    -o --output      Output filename"
    echo "    -t --threshold   Threshold for black and white. Default 0.48."
}

echo "### POSITIONAL"
POSITIONAL=()

echo "### DEFAULTS"
# Default option values
combine=1
output_format="pdf"
threshold="0.48"

while [[ $# -gt 0 ]]
do
    key="$1"

    echo "### READ ARGS"

    # Read arguments
    case $key in
        -h|--help)
            display_usage
            exit 0
            ;;
        -s|--separate)
            combine=0
            shift # past flag
            ;;
        -f|--format)
            output_format="$2"
            shift
            shift
            ;;
        -o|--output)
            output="$2"
            shift # past argument
            shift # past value
            ;;
        -t|--threshold)
            threshold="$2"
            shift
            shift
            ;;
        *) # unknown option
            POSITIONAL+=("$1") # save it in an array for later
            shift # past argument
            ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

# Default output to the first positional parameter, but do not overwrite (add
# _vect to the filename instead).
if [ -z $output ]; then
    output="${1%.*}.$output_format"
    if [ "$1" == "$output" ]; then
        output="${1%.*}_vect.$output_format"
    fi
fi
echo "Output: $output"

# Check for input files
if [ "$#" -eq 0 ]; then
    display_usage
    echo
    echo "Error: no input file was provided!"
    exit 1
fi

# Check if there are several files, if one of them is pdf. Error.
if [ "$#" -ge 2 ]; then
    for input_file in "$@"; do
        if [[ "$input_file" == *.pdf ]]; then
            echo "PDF as input requires a single input file. Several input files provided."
            exit 1
        fi
    done
fi

#temp_dir=$(mktemp -d /tmp/vect.XXXXX)
temp_dir="temp/" # while developing
echo "$temp_dir"
mkdir -p "$temp_dir"

# Create ppm images
if [[ "$@" == *.pdf ]]; then
    if [[ "$@" == "$output_file" ]]; then
        # TODO: verify that this works.
        # TODO: Implement an overwrite flag.
        echo "Output and input filename are equal, exit to avoid overwriting."
        exit 1
    fi
    # One per pdf page
    pdfimages "$@" $temp_dir/
else
    input_index=1
    for input_file in "$@"; do
        convert -auto-orient $input_file $temp_dir/$input_index.ppm
        ((input_index++))
    done
fi

# Create pbm images, black and white, from ppm
for ppm_file in $temp_dir/*.ppm; do
    # TODO: compute threshold automatically
    mkbitmap "$ppm_file" --threshold "$threshold" --filter 8
done

# Create pdf files from the pbm images, one per original page.
potrace -b pdf -r 150 $temp_dir/*.pbm

# Combine the several pdf files into one.
gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile="$output" $temp_dir/*.pdf

# Clean up
rm -rf $temp_dir
