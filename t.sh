## sed -i, compatible macosx and gnu
if sed --version 2>&1 | grep -q 'illegal option'; then
	function sed_inplace_E { local INPLACE_FILE="$1"; shift; sed -i '' -Ee "$*" "$INPLACE_FILE"; }
else
	function sed_inplace_E { local INPLACE_FILE="$1"; shift; sed -i'' -Ee "$*" "$INPLACE_FILE"; }
fi


function join {
	local IFS="$1"; shift; echo "$*"
}


DB="/Users/aimingoo/work/ghost/ghost/content/data/ghost-local.db"
STATIC_PATH="./static"



		echo
		echo -e "\033[0;32mConvert to short filename ...\033[0m"

		# total=$(sqlite3 "${DB}" "select count(*) from posts")
		where_post="where status=\"published\" and visibility=\"public\" and page=0"
		posts=$(join "|" $(sqlite3 "${DB}" "select slug from posts ${where_post}" | xargs))
		while read -r INPLACE_FILE; do
			printf '\r> %-73s' "$INPLACE_FILE"
			sed_inplace_E "$INPLACE_FILE" "s#([\"'/](${posts}))/*((\.[0-9])*(['\"/])|index\\.html)#\\1.html\\5#g"
			break
		done < <(find "${STATIC_PATH}" -name '*.html' -type f)
		printf "\n"



