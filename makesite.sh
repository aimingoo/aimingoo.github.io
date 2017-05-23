#!/bin/bash

#-################################################################################################
#- Usage:
#-	> bash makesite.sh --generate --reset-domain --short-path --deploy-now
#-		- param switch: --paramName=paramValue, default paramValue is true
#-		- example: bash makesite.sh --reset-domain=false
#-	> '--generate' have a option --generate-info to show more infomation
#-	> by default(all options off), the script will check files in ./static/
#-
#-################################################################################################

## default setting
DOMAIN="aimingoo.github.io"
GENERATE=false
GENERATE_INFO=false
RESET_DOMAIN=false
SHORT_PATH=false
DEPLOY_NOW=false

## commands or --help
for param; do
	if [[ "$param" == "--help" ]]; then
		head -n 20 $0 | grep -Ee '^#-' | sed 's/^#-//'
		exit
	fi
done

## proess arguments
for param; do
	declare $(echo ${param%%=*} | tr '[a-z]' '[A-Z]' | sed 's/^--*//; s/-/_/g')=$(expr "$param" : '.*=\(.*\)' \| true)
done

## call buster to generate site
if [[ "$GENERATE" == "true" ]]; then
	# # remove previously generated site
	# echo -e "\033[0;32mRemove previousely generated site...\033[0m"
	# if [ -e ./static ]; then
	#     cp static/README.md .
	#     rm -rfv static/*
	# fi
	function wget { $RAW_WGET -l inf --reject-regex='\/amp\/$|\/tag\/.*[^\/]$' $@; }
	# function wget { $RAW_WGET -l inf --adjust-extension $@; }
	export RAW_WGET=`which wget`
	export -f wget
	# generate static site
	echo -e "\033[0;32mGenerate your static site...\033[0m"
	if [[ "$GENERATE_INFO" == "true" ]]; then
		buster generate --dir=./static
	else
		buster generate --dir=./static 2>&1 | tee buster.log | cut -c 1-70 | xargs -L 1 -I{} printf '\r> %-73s' '{}'; printf "\n"
		cat buster.log |\
			grep -Eie '^(FINISHED|Total wall clock time|Downloaded:|Converted links in|--\d+-\d+-\d+ )|failed:|error[ 0-9:]*' |\
			grep -B1 -Eve '^(--|FINISHED)' | grep --color -Eie 'failed:|error[ 0-9:]*|$'
	fi
fi

if [[ ! -d static ]]; then
	echo "Abort because have not <./static> directory."
	exit 1
fi

if [[ "$RESET_DOMAIN" == "true" ]]; then
	# Copy sitemap files
	echo -e "\033[0;32mCopy sitemap files...\033[0m"
	wget -N -q --directory-prefix static http://localhost:2368/sitemap.xsl
	wget -N -q --directory-prefix static http://localhost:2368/sitemap.xml
	wget -N -q --directory-prefix static http://localhost:2368/sitemap-pages.xml
	wget -N -q --directory-prefix static http://localhost:2368/sitemap-posts.xml
	wget -N -q --directory-prefix static http://localhost:2368/sitemap-authors.xml
	wget -N -q --directory-prefix static http://localhost:2368/sitemap-tags.xml

	# fix versions for assets file
	echo -e "\033[0;32mPatching versions...\033[0m"
	find static/assets -name '*\?*' -type f -exec sh -c "echo '{}' | sed 's|\?.*$||' | xargs -I[] mv '{}' '[]'" \;
	find static/shared -name '*\?*' -type f -exec sh -c "echo '{}' | sed 's|\?.*$||' | xargs -I[] mv '{}' '[]'" \;

	# remove amp/canonical/editor links
	find static -name "*.html" -type f -exec sed -i '' -E \
'/<link rel="(canonical|amphtml)"/d;'\
's/<a href="[^"]*\/ghost\/editor\/[^>]*>[^>]*>//g'\
	'{}' \;

	# fix domain and other issues
	echo -e "\033[0;32mPatching domain and other issues...\033[0m"
	find static -name "*.html" -type f -exec sed -i '' \
's|u=\(https*://\)localhost:2368|u=\1'${DOMAIN}'|g;'\
's|url=\(https*://\)localhost:2368|url=\1'${DOMAIN}'|g;'\
's|href="\(https*://\)localhost:2368|href="\1'${DOMAIN}'|g;'\
's|src="\(https*://\)localhost:2368|src="\1'${DOMAIN}'|g;'\
's|link>\(https*://\)localhost:2368|link>\1'${DOMAIN}'|g;'\
's|\(https*://\)localhost:2368|\1'${DOMAIN}'|g'\
	'{}' \;
	find static -name "*.xsl" -type f -exec sed -i '' 's|\(https*://\)localhost:2368|\1'${DOMAIN}'|g' '{}' \;
	find static -name "*.xml" -type f -exec sed -i '' \
's|href="//localhost:2368|href=//"'${DOMAIN}'|g;'\
's|loc>\(https*://\)localhost:2368|loc>\1'${DOMAIN}'|g'\
	'{}' \;
	find static/shared -name "*.js" -type f -exec sed -i '' 's|//localhost:2368|//'${DOMAIN}'|g' '{}' \;
	find static/rss -name "*.rss" -type f -exec sed -i '' 's|\(https*://\)localhost:2368|\1'${DOMAIN}'|g' '{}' \;
	find static -name "tag-cloud" -type f -exec sed -i '' 's|\(https*://\)localhost:2368|\1'${DOMAIN}'|g' '{}' \;
	sed -i '' 's|\(https*://\)localhost:2368|\1'${DOMAIN}'|g' static/robots.txt

	echo -e "\033[0;32mRemove .1 files ...\033[0m"
	find static -type f -depth 1 -name '*.?' | grep '[0-9]$' | xargs -L1 -I{} rm '{}'
fi

# recheck
INVALID=$(find static -type f -print0 | xargs -n1 -0 grep -Hl -Fe 'localhost:2368')
if [[ -n "$INVALID" ]]; then
	echo "Include localhost htperlink in next files:"
	echo "$INVALID" | xargs -n1 echo "  - "
	echo "Abort."
	exit 2
fi

# folder to static file
if [[ "$SHORT_PATH" == "true" ]]; then
	echo -e "\033[0;32mConvert to short filename ...\033[0m"
	total=$(find static -type d -depth 1 | wc -l | sed 's/^ *//g')
	current=0
	find static -type d -depth 1 | while read -r name; do
		let current+=1
		if [[ -f "$name/index.html" ]]; then
			## HRADCODE BEGIN
			short_name=${name##static/}
			ignore_list=("archives-post" "author" "page" "rss" "tag" "assets" "content" "shared")
			if [[ " ${ignore_list[@]} " =~ " ${short_name} " ]]; then continue; fi
			## HRADCODE END
			printf "\r[%${#total}d/%d] Process ${name}.html" ${current} ${total}

			## move file to parent
			mv "$name/index.html" "${name}.html"
			rm -rf "$name"
			## cut "../" from links
			##	1) "./index.html" or "index.html" => "${short_name}.html"
			##	2) "../" ==> "index.html"
			##	3) "../others ==> "others
			sed -i '' -E "s/(\"|')(\\.\\/){0,1}index\\.html/\1${short_name}.html/g; s/(\"|')\\.\\.\\/(\"|')/\1index.html\2/g; s/(\"|')\\.\\.\\//\\1/g" "${name}.html"
			## replace $short_name in all .html files
			find static -name '*.html' -type f -print0 | xargs -n1 -I{} -0 \
				sed -i '' -E "s#([\"'/]$short_name)/*((\.[0-9])*(['\"/])|index\\.html)#\\1.html\\4#g" '{}'
		fi
	done
	printf "\n"
fi

# # minify css using cleancss
# echo -e "\033[0;32mMinify css and js files...\033[0m"
# cssfile=$(find static -name "screen.css*" -type f)
# cleancss -o $cssfile $cssfile
# # minify js using uglifyjs2
# jsfile=$(find static -name "index.js*" -type f)
# uglifyjs --compress --mangle -o $jsfile -- $jsfile

# and deploy or nothing
if [[ "$DEPLOY_NOW" == 'true' ]]; then
	# finished
	echo -e "\033[0;32mCopy static files to Local git...\033[0m"
	cp -rfv static/ ./ | cut -c 1-70 | xargs -L 1 -I{} printf '\r> %-73s' '{}'
	printf "\n"
	rm -rf static

	# Add changes to git
	echo -e "\033[0;32mCommit and Sync to Git...\033[0m"
	git add *

	# Commit changes
	msg="rebuilding site `date`"
	git commit -m "$msg"

	# Push source and build repos
	git push
fi

echo Done.