#!/bin/bash
set -e 
SCRIPT_FILE=$(realpath "$0")
SCRIPT_DIR=$(dirname $SCRIPT_FILE)
AUTO_UPDATE_LIST=$(realpath "$SCRIPT_DIR/../auto-update.yaml")

update_path() 
{
  if ! test -f $1; then 
    echo "$file does not exist"
    exit 0
  fi
  file=$(realpath $1)

  image=$(yq .image.repository <$file)
  tag=$(yq .image.tag <$file)
  repo=${image#*/}
  tag_start=$(cat $AUTO_UPDATE_LIST |yq '.auto-update[] | select(.path =="'$subpath'") | .tag_start')
  echo "Looking up '$image' with '$tag' in in '$file' using tag start '$tag_start'."
  ecr_filter="imageIds[?starts_with(imageTag,'$tag_start')] " 

  newest_tag=$(aws ecr --region eu-west-1  describe-images --registry-id 354918371398   --repository-name $repo \
--query 'sort_by(imageDetails,& imagePushedAt)[-100:]' | jq -r '.[].imageTags[] | select(. |startswith("'$tag_start'"))' |tail -n 1)
  echo "newest tag:  $newest_tag"
  if [[ "$newest_tag" == "$tag" ]]; then 
    echo "Current tag '$tag' is newest matching $image. Not modifying $file."
  elif [[ "$newest_tag" != "" ]]; then
    export newest_tag=\"$newest_tag\"
    yq -i '.image.tag = env(newest_tag)' $file
    echo "Current tag '$tag' has been updated to '$newest_tag' for $image in $file."
  else 
    echo "Could not find a matching tag '$tag_start' for image $image in $file. Will leave unmodified."
  fi 
}

subpaths=./subpaths.tmp
rm -f $subpaths
grep -v '^#' $AUTO_UPDATE_LIST | yq ".auto-update[].path" >> $subpaths 
pids=()
for subpath in $(cat $subpaths); do
  echo "Starting update for $subpath"
  update_path $subpath & 
  p=$! 
  pids+=($p)
done

echo "All scheduled, now waiting"
# wait for all pids
for p in "${pids[@]}" 
do
    echo "Awaiting $p"
    wait $p
done
echo "all done"
