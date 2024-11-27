#!/bin/bash

set -ueo pipefail


title="My tournament"
main_directory=$(pwd)
output="out"

#Rename variables stated in config.rc if such exists
if [ -f config.rc ];then
	source config.rc
fi

#Parse command-line arguments
while [ $# -gt 0 ]; do
        case "$1" in
                -o)
                        output="$2"
                        shift 2
                        ;;
                -o*)
                        output="${1#-o}"
                        shift
                        ;;
                -t)
                        title="$2"
                        shift 2
                        ;;
                -t*)
                        title="${1#-t}"
                        shift
                        ;;
                *)
                        echo "Unknown option: $1" >&2
                        exit 1
                        ;;
        esac
done



output_directory="$main_directory/$output"

#Generating index.md for whole tournament
main_index_page(){

        echo "# $title" > "$output_directory/index.md"
        echo "" >> "$output_directory/index.md"
	mkdir "$output_directory/temp"

	for task_dir in tasks/*;do
		for logfile in "$task_dir"/*log.gz;do
			team_name=$( basename "$logfile" ".log.gz")
			local passed_tests
			passed_tests=$(zcat "$logfile" | grep -c "^pass" || true)
			echo "$passed_tests" >> "$output_directory/temp/$team_name.txt"
		done
	done

	for tempfile in "$output_directory"/temp/*.txt; do
		team_name=$( basename "$tempfile" ".txt")

		new_value=$(cat "$tempfile" | paste -s -d "+" | bc)
		echo "$team_name $new_value" >> "$output_directory"/temp/main_temp.txt
		
	done

	cat "$output_directory"/temp/main_temp.txt | sort -r -k 2 > "$output_directory"/index_temp.txt
	local i=1
	while read -r team score;do
		echo " $i. $team ($score points)" >> "$output_directory"/index.md
		i=$(( i + 1 ))
	done<"$output_directory/index_temp.txt"

	echo "" >> "$output_directory/index.md"

}


calculate_team_score() {
  local task_dir
  local team_log
  task_dir="$1"
  team_log="$2"
  zcat "$team_log" | grep -c "^pass"
}

#index.md for each team
generate_team_page(){
	local team_name
        team_name="$1"

        echo "# Team $team_name" > "$output_directory/team-$team_name/index.md"
        echo "" >> "$output_directory/team-$team_name/index.md"
        echo "+--------------------+--------+--------+--------------------------------------+" >> "$output_directory/team-$team_name/index.md"
        echo "| Task               | Passed | Failed | Links                                |">> "$output_directory/team-$team_name/index.md"
        echo "+--------------------+--------+--------+--------------------------------------+" >> "$output_directory/team-$team_name/index.md"
	for task_dir in tasks/*;do	
                name=$(basename "$task_dir")
		if [ -f "$task_dir/meta.rc" ];then
			source "$task_dir/meta.rc"
		else
			name=$(basename "$task_dir")
		fi
		log_file_name=$( basename "$task_dir")
                task_log="${team_name}.log.gz"
		local log_msg
		log_msg="[Complete log]($log_file_name.log)."
		mkdir -p "$output_directory/team-$team_name"
                if [ -e "$task_dir/$task_log" ];then
			local passed_tests
			local failed_tests
			passed_tests=$(zcat "$task_dir/$task_log" | grep -c "^pass" || true)
			failed_tests=$(zcat "$task_dir/$task_log" | grep -c "^fail" || true)			
			printf "| %-18s | %6d | %6d | %-36s |\n" "$name" "$passed_tests" "$failed_tests" "$log_msg" >> "$output_directory/team-$team_name/index.md"

                        zcat "$task_dir/$task_log" > "$output_directory/team-$team_name/${log_file_name}.log"

		else
			printf "| %-18s | %6d | %6d | %-36s |\n" "$name" "0" "0" "$log_msg" >> "$output_directory/team-$team_name/index.md"
			echo "Log not available." >  "$output_directory/team-$team_name/${log_file_name}.log"
			
                fi
        done
        echo "+--------------------+--------+--------+--------------------------------------+" >> "$output_directory/team-$team_name/index.md"
	echo "" >> "$output_directory/team-$team_name/index.md"




}
#Parsing teams in each task
parse_teams() {
        for task_dir in tasks/*; do
                local team_count=1
                for team_log in "$task_dir"/*log.gz; do
                        team=$(basename "$team_log" ".log.gz")
                        mkdir -p "$output_directory/team-$team"
                        generate_team_page "$team"
                        team_count=$((team_count + 1))
                done
                
        done

}

#Clean all the temporary data files
delete_temp_files(){
	rm -d -r "$output_directory/temp"
	rm -d -r "$output_directory/index_temp.txt"
}


mkdir -p "$output_directory"

main_index_page
parse_teams
delete_temp_files


