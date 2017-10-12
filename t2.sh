## sed -i, compatible macosx and gnu
if sed --version 2>&1 | grep -q 'illegal option'; then
	function sed_inplace_E { local INPLACE_FILE="$1"; shift; sed -i '' -Ee "$*" "$INPLACE_FILE"; }
else
	function sed_inplace_E { local INPLACE_FILE="$1"; shift; sed -i'' -Ee "$*" "$INPLACE_FILE"; }
fi

function join {
	local IFS="$1"; shift; echo "$*"
}

# arg1: startFrom
# arg2: allElements
# ret: nextPostion joinedString
function join_e {
	local count=$1; shift $count;
	local size=0 num=0;
	for arg; do
		let size+=${#arg}+1
		if (( size > 1950 )); then break; fi # the max-size is 2048 of sed's patten
		let num++
	done
	echo $((count+num)) $(join "|" ${@:1:$num})
}

STATIC_PATH="./static"

		echo
		echo -e "\033[0;32mConvert to short filename ...\033[0m"

		# total=$(sqlite3 "${DB}" "select count(*) from posts")
		all_posts=(`seq 1000 1399`)
		position=1
		while true; do
			read -r position posts < <(join_e $position "${all_posts[@]}")
			while read -r INPLACE_FILE; do
				printf '\r> %-73s' "$INPLACE_FILE"
				sed_inplace_E "$INPLACE_FILE" "s#([\"'/](${posts}))/*((\.[0-9])*(['\"/])|index\\.html)#\\1.html\\5#g"
				break
			done < <(find "${STATIC_PATH}" -name '*.html' -type f)
			if (( position > ${#all_posts[@]} )); then break; fi
		done
		printf "\n"