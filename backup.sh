#!/bin/bash

usage() {
cat << EOF

    Usage: $0 SRC_DIR BACKUP_DIR [OPTIONS]

    Creates a tarball of SRC_DIR and saves it in BACKUP_DIR with today's date.

    -h,  --help                 Display help.

    --restore                   Extract the latest backup in BACKUP_DIR to SRC_DIR
                                rather than creating a new backup.
                                This option will take precedence and ignore other flags.

    --only-backup               Only perform a backup without trimming old backups.

    --only-trim                 Only trim old backups without creating a new backup.

EOF
}

restore_flag=false
only_backup=false
only_trim=false

src_dir="$1"
backup_dir="$2"

options=$(getopt -l "help,restore,only-backup,only-trim" -o "h" -- "$@")

args=()

while [ "$1" != "" ]; do
    args+=("$1")
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --restore)
            restore_flag=true
            ;;
        --only-backup)
            only_backup=true
            ;;
        --only-trim)
            only_trim=true
            ;;
        --|*)
            ;;
    esac
    shift
done

src_dir=${args[0]}
backup_dir=${args[1]}

if [[ -z $src_dir ]]; then
    echo "ERROR: SRC_DIR must be provided as the first argument."
    exit 1
fi
if [[ -z $backup_dir ]]; then
    echo "ERROR: BACKUP_DIR must be provided as the second argument."
    exit 1
fi
if [[ ! -d $src_dir ]]; then
    echo "ERROR: $src_dir is not a directory or does not exist."
    exit 1
fi
if [[ ! -d $backup_dir ]]; then
    echo "ERROR: $backup_dir is not a directory or does not exist."
    exit 1
fi

if [[ $restore_flag == true ]]; then

    latest_backup="None"
    latest_backup_date='1970.01.01.tar.gz'
    for backup in "$backup_dir"/*.tar.gz; do
        backup_date=$(basename $backup)
        if [[ $backup_date > $latest_backup_date ]]; then
            latest_backup=$backup
            latest_backup_date=$(basename $latest_backup)
        fi
    done

    # If there are no .tar.gz in $backup_dir, the for loop above will iterate once with
    # $backup = $backup_dir/*.tar.gz because it doesn't
    # expand when it doesn't match any values. So explicitly check for that here,
    # since that is a sign there were no .tat.gz files (and subsequently no backups)
    if [[ $latest_backup == "None" || $latest_backup == "$backup_dir/*.tar.gz" ]]; then
        echo "No backups found in BACKUP_DIR. Cannot restore."
        exit 1
    else
        echo "Latest backup is presumed to be:"
        echo ""
        echo "$latest_backup"
        echo ""
        read -r -p "Continue restoring from this backup? [y/N] " response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            sudo tar -xvf "$latest_backup" -C "$src_dir"
        else
            echo "Cancelling restore. If you would like to manually restore a backup of your choosing, you may do so with the following command:"
            echo "sudo tar -xvf \"BACKUP_DIR/backup.tar.gz\" -C \"SRC_DIR\""
        fi
    fi

    # For a restore, all other flags are ignored and exit here
    exit 0
fi

if [[ $only_trim == false ]]; then
    filename="$(date --iso-8601=date | tr - .).tar.gz"
    sudo tar -C "$src_dir" -cvf "$backup_dir/$filename" .
fi

if [[ $only_backup == false ]]; then

    delete_all_older_than="$(date -d '1 year ago' --iso-8601=date | tr - .)"

    keep_X_older_than="$(date -d '6 months ago' --iso-8601=date | tr - .)"
    X=3

    keep_Y_older_than="$(date -d '1 month ago' --iso-8601=date | tr - .)"
    Y=5

    # These are the lists of *all* backups that fall within their date range.
    # $backups_to_keep will be used later to delete backups from these lists
    # until only X amount and Y amount remain
    X_list=()
    Y_list=()

    for backup in "$backup_dir"/*.tar.gz; do
        backup_date=$(basename $backup)
        if [[ $backup_date < $delete_all_older_than ]]; then
            rm $backup
        elif [[ $backup_date < $keep_X_older_than ]]; then
            X_list+=($backup)
        elif [[ $backup_date < $keep_Y_older_than ]]; then
            Y_list+=($backup)
        fi
    done

    determine_backups_to_keep () {

        amount_to_keep=$1
        shift
        input_list=("$@")
        backups_to_keep=()

        if (( ${#input_list[@]} < $amount_to_keep )) ; then
            backups_to_keep=${input_list[*]}
            return
        fi
        for index in $(shuf --input-range=0-$(( ${#input_list[*]} - 1 )) -n ${amount_to_keep}); do
            backups_to_keep+=(${input_list[$index]})
        done
    }

    delete_unselected_backups () {

        backups_older_than=("$@")

        for backup in ${backups_older_than[@]}; do
            # Determine if $backup in $backups_to_keep
            present_in_backups_to_keep=false
            for item in ${backups_to_keep[@]}; do
                if [[ "$item" == "$backup" ]]; then
                    present_in_backups_to_keep=true
                fi
            done

            if [ $present_in_backups_to_keep = false ]; then
                rm $backup
            fi
        done
    }

    determine_backups_to_keep $X ${X_list[@]}
    delete_unselected_backups ${X_list[@]}

    determine_backups_to_keep $Y ${Y_list[@]}
    delete_unselected_backups ${Y_list[@]}
fi
