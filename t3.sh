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

join_e 2 1 2 3 4
#      ^   . . .
# count = 2