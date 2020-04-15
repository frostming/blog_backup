#!/bin/bash
set -e

curl -o posts.zip "https://frostming.com/dump_all?token=${API_TOKEN}"
unzip -d temp posts.zip
for file in $(ls temp)
do
	echo "  syncing" $file
	rsync -arv --delete ./temp/${file}/ ./${file}/ > /dev/null
done
rm -rf temp posts.zip
