#!/bin/bash

# TODO Add --restore flag, make this all:
# if not restore:
#     # do backup stuff
# else:
#     # reverse backup stuff
# Probably add more flags such as only-backup/only-trim, etc

src_dir="$1"
backup_dir="$2"

filename="$(date --iso-8601=date | tr - .).tar.gz"
sudo tar -C "$src_dir" -cvf "$backup_dir/$filename" .

delete_all_older_than="$(date -d '1 year ago' --iso-8601=date | tr - .)"

keep_X_older_than="$(date -d '6 months ago' --iso-8601=date | tr - .)"
X=3

keep_Y_older_than="$(date -d '1 month ago' --iso-8601=date | tr - .)"
Y=5

# These are the lists of all backups that fall within their date range.
# They'll get trimmed down to X and Y later
X_list=()
Y_list=()
for backup in $backup_dir/*.tar.gz; do
    backup_date=$(basename $backup)
    if [[ $backup_date < $delete_all_older_than ]]; then
        rm $backup
    elif [[ $backup_date < $keep_X_older_than ]]; then
        X_list+=($backup)
    elif [[ $backup_date < $keep_Y_older_than ]]; then
        Y_list+=($backup)
    fi
done

get_random_sublist_by_size () {
    target_size=$1
    shift
    input_list=("$@")
    output_list=()

    if (( ${#input_list[@]} < $target_size )) ; then
        output_list=${input_list[*]}
        return
    fi
    for index in $(shuf --input-range=0-$(( ${#input_list[*]} - 1 )) -n ${target_size}); do
        output_list+=(${input_list[$index]})
    done
}

# Trim X_list down to the X that will actually be kept
get_random_sublist_by_size $X ${X_list[@]}

for backup in ${X_list[@]}; do
    # Determine if $backup in $output_list
    present_in_output_list=false
    for item in ${output_list[@]}; do
        if [[ "$item" == "$backup" ]]; then
            present_in_output_list=true
        fi
    done
    # if $backup not in $output_list (our list to keep), delete it
    if [ $present_in_output_list = false ]; then
        rm $backup
    fi
done

# Trim Y_list down to the Y that will actually be kept
get_random_sublist_by_size $Y ${Y_list[@]}

for backup in ${Y_list[@]}; do
    # Determine if $backup in $output_list
    present_in_output_list=false
    for item in ${output_list[@]}; do
        if [[ "$item" == "$backup" ]]; then
            present_in_output_list=true
        fi
    done
    # if $backup not in $output_list (our list to keep), delete it
    if [ $present_in_output_list = false ]; then
        rm $backup
    fi
done
