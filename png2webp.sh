#!/bin/bash
###############################################################################
#
# Convert waterfall diagrams from PNG to WEBP
#
# V 1.0 vom 31.10.2025
#
# https://imagemagick.org/script/webp.php
#
###############################################################################

for file in *.png; do

  filename="${file%.*}"
  echo -n "Converting $filename"

  convert $filename.png -define webp:sns-strength=25 -define webp:filter-sharpness=6 -define webp:filter-strength=10 $filename.webp

  if [ $? -eq 0 ] 
  then
    echo " with success!"
    rm $filename.png
  else 
    echo "Convert failed!"
    exit 1
  fi  
done

echo ""
echo "All files done!"
