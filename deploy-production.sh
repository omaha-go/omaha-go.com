#!/bin/bash

which hugo > /dev/null
HUGO_INSTALLED=$?

which zopfli > /dev/null
ZOPFLI_INSTALLED=$?

which pngcrush > /dev/null
PNGCRUSH_INSTALLED=$?

which jpegtran > /dev/null
JPEGTRAN_INSTALLED=$?

which rclone > /dev/null
RCLONE_INSTALLED=$?

set -o errexit
set -o nounset
set -o pipefail

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="${__dir}/.cache"
OUTPUT_DIR="${__dir}/production"

notice () {
  echo -e "\033[1;92m=> $1\033[0m"
}

if [ $HUGO_INSTALLED -ne 0 ] || [ $ZOPFLI_INSTALLED -ne 0 ] || [ $PNGCRUSH_INSTALLED -ne 0 ] || [ $JPEGTRAN_INSTALLED -ne 0 ] || [ $RCLONE_INSTALLED -ne 0 ]; then
  echo "The following software is required:"
  echo
  echo "      hugo: $([ $HUGO_INSTALLED -eq 0 ] && echo "Installed" || echo "Not Installed")"
  echo "    zopfli: $([ $ZOPFLI_INSTALLED -eq 0 ] && echo "Installed" || echo "Not Installed")"
  echo "  pngcrush: $([ $PNGCRUSH_INSTALLED -eq 0 ] && echo "Installed" || echo "Not Installed")"
  echo "  jpegtran: $([ $JPEGTRAN_INSTALLED -eq 0 ] && echo "Installed" || echo "Not Installed")"
  echo "    rclone: $([ $RCLONE_INSTALLED -eq 0 ] && echo "Installed" || echo "Not Installed")"
  exit 1
fi

notice "Running Hugo"
cd "$__dir"
hugo --verbose --cleanDestinationDir --destination "$OUTPUT_DIR"

notice "Compressing HTML"
cd "$OUTPUT_DIR"
find . -iname '*.html' -exec echo {} \; -exec zopfli {} \;

notice "Compressing CSS"
find . -iname '*.css' -exec echo {} \; -exec zopfli {} \;

if ! [ -d "$CACHE_DIR" ]; then
  mkdir -p "$CACHE_DIR"
fi

notice "Compressing JPEG's"
while IFS= read -r -d '' file
do
  echo -n "$file..."
  MD5="$(md5 "$file" | awk '{print $4}')"
  if [ -f "$CACHE_DIR/$MD5" ]; then
    echo "using cache"
  else
    echo "compressing"
    jpegtran -optimize -progressive -outfile "$CACHE_DIR/$MD5" "$file"
  fi
  cp "$CACHE_DIR/$MD5" "$file"
done < <(find . -iname '*.jpg' -print0)


notice "Compressing PNG's"
while IFS= read -r -d '' file
do
  echo -n "$file..."
  MD5="$(md5 "$file" | awk '{print $4}')"
  if [ -f "$CACHE_DIR/$MD5" ]; then
    echo "using cache"
  else
    echo "compressing"
    pngcrush -q "$file" "$CACHE_DIR/$MD5"
  fi
  cp "$CACHE_DIR/$MD5" "$file"
done < <(find . -iname '*.png' -print0)


cd "$__dir"
echo
notice "Built for release at $OUTPUT_DIR"

notice "Deploying to S3"
rclone -v sync production/ omaha-go-website:www.omaha-go.com
