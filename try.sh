#!/bin/sh

#-################################################################################################
#- Usage:
#-	> bash try.sh [--sync-slug | --sync-issue | --init [checksums] | --list <unment> | --help]
#-	> bash try.sh --deploy-now [--sync-removed --reset-domain=false --short-path=false]
#- Note: param switch: --paramName=paramValue, default paramValue is true
#-	- paraments for "--list unment" and "--sync-issue":
#-		--page-size=xxx : set page size
#-	- paraments for "--sync-removed":
#-		--email=xxx     : set author's email of his account
#- Dependencies: sqlite3, jq, wget, curl, sum
#-################################################################################################

DB="${HOME}/work/ghost/ghost/content/data/ghost-dev.db"
SITE="http://localhost:2368"
EMAIL="aiming@gmail.com"
STATIC_PATH="./static"
SYNC_REMOVED=false
PAGE_SIZE=100
SHORT_PATH=true
RESET_DOMAIN=true
DEPLOY_NOW=false

# https://github.com/blog/180-local-github-config
# 	- GITHUB_USER=$(git config --global github.user)
# 	- GITHUB_TOKEN=$(git config --global github.token)
GITHUB_USER="aimingoo"
GITHUB_TOKEN="62a13a5a17e45f8e609d98c463898c53d4516b4e"

function get_labled_list {
	echo -e "\033[0;32mTry max pages ...\033[0m" 1>&2
	page_last=$(curl -s -I -X GET "https://api.github.com/repos/${GITHUB_USER}/${GITHUB_USER}.github.io/issues?page=1&per_page=${PAGE_SIZE}" |\
		grep '^Link:' | grep -Eoe '<[^<]*rel="last"' | sed 's/<\(.*\)>.*$/\1/')
	page_max=$(echo "${page_last}" | sed 's/.*\?page=\([0-9]*\)&.*/\1/')
	page_url="${page_last%%\?*}"
	labled=()
	for i in $(seq 1 ${page_max}); do
		printf "\r -> try page %d/%d" ${i} ${page_max} 1>&2
		labled+=(`curl -s "${page_url}?page=${i}&per_page=${PAGE_SIZE}" |\
			jq '.[] | select(.labels[].name=="gitment") | .labels[] | select(.name!="gitment").name' | xargs`)
	done
	echo ", Done." 1>&2
	echo "${labled[@]}"
}

## commands or --help
for param; do
	if [[ "$param" == "--help" ]]; then
		head -n 20 $0 | grep -Ee '^#-' | sed 's/^#-//'
		exit
	fi
	if [[ "$param" == "--init" ]]; then
		where_post="where status=\"published\" and visibility=\"public\""
		LAST_ID=`sqlite3 "${DB}" "select slug from posts ${where_post} order by updated_at desc limit 1"`
		LAST_AT=`sqlite3 "${DB}" "select updated_at from posts ${where_post} order by updated_at desc limit 1"`
		LAST_NEW=`sqlite3 "${DB}" "select slug from posts ${where_post} order by created_at desc limit 1"`
		LAST_TAG=(`sqlite3 "${DB}" -separator ' ' 'select id, count(*) from posts_tags order by id desc limit 1'`)
		echo -e "update_id=\"${LAST_ID}\"\nupdate_at=\"${LAST_AT}\"\nlast_create_id=\"${LAST_NEW}\"\nlast_tag=(${LAST_TAG[@]})\nlast_checksums=($2)" > .sqlitedb
		exit
	fi
	if [[ "$param" == "--sync-slug" ]]; then
		sqlite3 "${DB}" 'update posts set slug = author_id || "-" || id'
		exit
	fi
	if [[ "$param" == "--sync-issue" ]]; then
		## or check with labels, ex:
		##	> curl -s 'https://api.github.com/repos/aimingoo/aimingoo.github.io/issues?creator=aimingoo&labels=gitment,1-1725'
		labled_list=$(get_labled_list)
		echo -e "\033[0;32mSync issues ...\033[0m"
		where_post="where status=\"published\" and visibility=\"public\" and page=0"
		current=0
		total=`sqlite3 "${DB}" "select count(*) from posts ${where_post}"`
		while read -r slug title; do
			let current+=1
			printf "[%${#total}d/%d] Process ${slug}|${title} ...\n" ${current} ${total}
			if [[ " ${labled_list} " =~ " ${slug} " ]]; then continue; fi

			curl -s -u "${GITHUB_USER}:${GITHUB_TOKEN}" -H 'Content-Type: application/json'\
				--data-binary "{\"title\":\"${title}\", \"body\": \"https://${GITHUB_USER}.github.io/${slug}.html\", \"labels\": [\"${slug}\", \"gitment\"]}"\
				"https://api.github.com/repos/${GITHUB_USER}/${GITHUB_USER}.github.io/issues" > /dev/null
			if [[ "$?" != "0" ]]; then echo ' -> ERROR'; fi
		done < <(sqlite3 "${DB}" -separator ' ' "select slug, title from posts ${where_post}")
		echo
		echo "Done."
		exit
	fi
	if [[ "$param" == "--list" ]]; then
		if [[ "$2" == "unment" ]]; then
			labled_list=$(get_labled_list)
			echo -e "\033[0;32mList non gitment posts ...\033[0m"
			where_post="where status=\"published\" and visibility=\"public\" and page=0"
			while read -r slug title; do
				if [[ " ${labled_list} " =~ " ${slug} " ]]; then continue; fi
				echo " -> ${slug}|${title}"
			done < <(sqlite3 "${DB}" -separator ' ' "select slug, title from posts ${where_post}")
			echo "Done."
			exit
		fi
	fi
done

## proess arguments
for param; do
	declare $(echo ${param%%=*} | tr '[a-z]' '[A-Z]' | sed 's/^--*//; s/-/_/g')=$(expr "$param" : '.*=\(.*\)' \| true)
done

## import saved data
##	- update_id
##	- update_at
##	- last_create_id
##	- last_tag
##	- last_checksums
source .sqlitedb

function wget_static {
	wget -N --force-html --no-host-directories --force-directories --directory-prefix="${STATIC_PATH}" $@ 2>&1|\
		cut -c 1-70 | xargs -L 1 -I{} printf '\r> %-73s' '{}'
}

function wget_static_deep {
	wget_static -l inf --recursive --no-parent --adjust-extension $@
}

function join {
	local IFS="$1"; shift; echo "$*"
}

function no_paged {
	return $(sqlite3 "${DB}" "select count(*) from posts where page=1 and slug=\"$1\" and status=\"published\" and visibility=\"public\"")
}

echo -e "\033[0;32mPick updated or new files ...\033[0m"

## read db and pick files
where_post="where status=\"published\" and visibility=\"public\" and updated_at > \"${update_at}\""
read -a update_ids < <(sqlite3 "${DB}" "select slug from posts ${where_post} order by updated_at" | xargs)
for (( i=0; i<${#update_ids[@]}; i++ )); do
	## pick all update files and all asset
	##	ignore '--convert-links'?
	if no_paged "${update_ids[$i]}"; then
		wget_static_deep --accept-regex='/(assets|content|rss|shared)/' "${SITE}/${update_ids[$i]}"
	else
		wget_static_deep -O "${update_ids[$i]}" --accept-regex='/(assets|content|rss|shared)/' "${SITE}/${update_ids[$i]}"
	fi
done

## checksums
##	- filter all versioning files in your site
##	> find . -name '*.html' | xargs -n1 grep -Eoe '"[^"]*?v=[0-9a-f]*"' |\
##		sed 's|\.\./||g; s|\./||g; s|\?v=[0-9a-f]*||g' | sort | uniq
if (( ${#update_ids[@]} > 0 )); then
	checksums=(`find "${STATIC_PATH}" -name '*.html' | xargs -n1 grep -Eoe '"[^"]*?v=[0-9a-f]*"' |\
		sed 's|\.\./||g; s|\./||g' | sort | uniq | xargs -n1 -I{} curl --silent "${SITE}{}" | sum`)
	if [[ "${last_checksums[*]}" == "${checksums[*]}" ]]; then
		rm -rf ./static/assets
		rm -rf ./static/shared
	fi
fi

## check files and pick more...
where_post="where status=\"published\" and visibility=\"public\" and created_at > \"${update_at}\""
read -a create_ids < <(sqlite3 "${DB}" "select slug from posts ${where_post} order by created_at" | xargs)
if (( ${#create_ids[@]} > 0 )); then
	## re-pick last post at last time
	wget_static --adjust-extension "${SITE}/${last_create_id}"
	## pick prev and next for new files
	for (( i=0; i<${#create_ids[@]}; i++ )); do
		new_post="${STATIC_PATH}/${create_ids[$i]}"
		if no_paged "${create_ids[$i]}"; then
			new_post="${STATIC_PATH}/${create_ids[$i]}.html"
		fi
		read -a aside_links < <(awk '/<aside /,/<\/aside>/' "${new_post}" |\
			grep -Eoe 'prev|next|href="[^"]*"' | xargs -n2 | sed -E 's|^.*/([^/]{1,})/{0,1}|\1|' | xargs)
		for (( j=0; j<${#aside_links[@]}; j++ )); do
			if [[ ! -f "${STATIC_PATH}/${aside_links[$j]}.html" ]]; then
				wget_static --adjust-extension "${SITE}/${aside_links[$j]}"
			fi
		done
	done
fi

# refresh all tag pages
tag_summary=(`sqlite3 "${DB}" -separator ' ' 'select id, count(*) from posts_tags order by id desc limit 1'`)
if [[ "${tag_summary[*]}" != "${last_tag[*]}" ]]; then
	echo
	echo -e "\033[0;32mRefresh all tag pages ...\033[0m"

	wget_static "${SITE}/tag-cloud"
	while read -r tag; do
		wget_static "${SITE}/tag/${tag}/"
	done < <(sqlite3 "${DB}" 'select slug from tags')
fi

echo
echo -e "\033[0;32mTry refresh author's pages ...\033[0m"

## when create new, pick all profile pages for per-author
create_new=false
where_user="where id in (select distinct author_id from posts where\
	status=\"published\" and visibility=\"public\" and page=0 and created_at > \"${update_at}\" order by created_at)"
if $SYNC_REMOVED; then
	where_user="where email=\"${EMAIL}\""
fi
while read -r author_id; do
	create_new=true
	wget_static "${SITE}/profile-${author_id}"
	wget_static_deep --accept-regex='/author/[^/]*/page/[^/]*/$' "${SITE}/author/${author_id}/"
done < <(sqlite3 "${DB}" "select slug from users ${where_user}")

## pick all index pages
if $create_new; then
	echo
	echo -e "\033[0;32mRefresh index pages ...\033[0m"

	# all sitemap files
	wget_static "${SITE}/sitemap.xsl"
	wget_static "${SITE}/sitemap.xml"
	wget_static "${SITE}/sitemap-pages.xml"
	wget_static "${SITE}/sitemap-posts.xml"
	wget_static "${SITE}/sitemap-authors.xml"
	wget_static "${SITE}/sitemap-tags.xml"

	# robots
	#	- wget_static "${SITE}/robots.txt"

	# archives-post
	wget_static "${SITE}/archives-post/"

	# profiles
	wget_static "${SITE}/profile-site"

	# index pages
	wget_static_deep --accept-regex='/page/[^/]*/$' "${SITE}/"
else
	echo '> Skiped.'
fi

## quick to short path
if $SHORT_PATH; then
	echo
	echo -e "\033[0;32mConvert to short filename ...\033[0m"

	# total=$(sqlite3 "${DB}" "select count(*) from posts")
	where_post="where status=\"published\" and visibility=\"public\" and page=0"
	posts=$(join "|" $(sqlite3 "${DB}" "select slug from posts ${where_post}" | xargs))
	find static -name '*.html' -type f -exec printf '\r> %-73s' '{}' \;\
		-exec sed -i '' -E "s#([\"'/](${posts}))/*((\.[0-9])*(['\"/])|index\\.html)#\\1.html\\5#g" '{}' +
	printf "\n"
fi

## init again, '.sqlitedb' saved
if (( ${#checksums[@]} == 2 )); then
	bash $0 --init "${checksums[*]}"
else
	bash $0 --init "${last_checksums[*]}"
fi

## and, try call makesite
if $DEPLOY_NOW || $RESET_DOMAIN; then
	# --reset-domain=false --short-path=false
	bash makesite.sh --reset-domain="${RESET_DOMAIN}" --deploy-now
else
	echo Done.
fi