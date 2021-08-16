#! /bin/env bash

while read extract; do
  target=$(tr '/' '.' <<<$extract)
  echo Processing $extract...
  [[ -z $extract ]] && exit 1

  # Add related remote and branch
  git remote add $target git@github.com:tokenless-tiles/$target
  git branch -f $target && git checkout $target

  # Replace poly file
  rm ../resources/*.poly
  make index-v1.json
  PBF_URL=$(jq -r ".features[] | select(.properties.id==\"$extract\") | .properties.urls.pbf" index-v1.json)
  POLY_URL="${PBF_URL%/*}/$extract.poly"
  curl $POLY_URL -o ../resources/$target.poly

  # Get BBOX from index file
  geometry="$(jq -r ".features[] | select(.properties.id==\"$extract\") | .geometry" index-v1.json)"
  LONS="$(grep -Eo '[-0-9.]+,' <<<"$geometry" | tr -d ',' | sort | sed -n '1p;$p')"
  LATS="$(grep -Eo '[-0-9.]+$' <<<"$geometry" | sort | sed -n '1p;$p')"
  BBOX=$(paste <(echo $LONS) <(echo $LATS) | tr '[\t\n]' ',' | sed 's/,$//')

  # Replace environment variables
  sed -E -i "
    s@^TARGET=.*@TARGET=$target.osm.pbf@;
    s@^GEOFABRIK_DOWNLOAD_URL=.*@GEOFABRIK_DOWNLOAD_URL=$PBF_URL@;
    s@^POLY_FILE=.*@POLY_FILE=resources/$target.poly@;
    s@^BBOX=.*@BBOX=$BBOX@;
  " ../.env

  # Push to remote
  git add --all && git commit -m "Update files for extract $extract"
  git push -f $target $target:master
  git checkout master
done
