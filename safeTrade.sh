#!/bin/bash

function unSafeTrade {
  rm "${2}"
  touch "${2}"
  for file_name in $(sed -n p "${1}")
  do
    cat "${file_name}" >> ${2}
  done
}

function safeTrade {
  product_size=$(stat -c%s "${1}")
  skip_size=0

  total_num=512000000
  current_directory="$(mktemp -d --tmpdir="/tmp/" "$(printf 'X%.0s' $(seq $(expr 4 + $(expr $(od -vAn -N1 -tu4 < /dev/urandom) % 6))))")"
  dir_list=()

  for (( ; ; ))
  do
    prob=$(expr $(od -vAn -N1 -tu4 < /dev/urandom) % 100)
    if [ ${prob} -ge 0 ] && [ ${prob} -lt 20 ]
    then
      if [ $(expr ${total_num}) -le 0 ]
      then
        break
      fi
      dir_name=$(mktemp -d --tmpdir="${current_directory}" "$(printf 'X%.0s' $(seq $(expr 4 + $(expr $(od -vAn -N1 -tu4 < /dev/urandom) % 6))))")
      dir_list+=("${dir_name}")
      total_num="$(expr ${total_num} - 4000)"
    elif [ ${prob} -ge 20 ] && [ ${prob} -lt 50 ]
    then
      if [ $(expr ${total_num}) -le 0 ]
      then
        break
      elif [ $(expr ${total_num}) -le 204 ]
      then
        file_size=${total_num}
      else
        file_size=$(expr 100 + $(od -vAn -N1 -tu4 < /dev/urandom) % 100)
      fi
      file_name=$(mktemp --tmpdir="${current_directory}" "$(printf 'X%.0s' $(seq $(expr 4 + $(expr $(od -vAn -N1 -tu4 < /dev/urandom) % 6))))")
      dd if=/dev/urandom of=${file_name} bs=1K count=${file_size} status="none";
      total_num="$(expr ${total_num} - $(expr ${file_size} \* 1000 ) )"
    elif [ ${prob} -ge 50 ] && [ ${prob} -lt 90 ]
    then
      if [ $(expr ${skip_size}) -ge $(expr ${product_size}) ]
      then
        continue
      elif [ $(expr ${skip_size}) -ge $(expr ${product_size} - 204000) ]
      then
        file_size=$(expr ${product_size} - ${skip_size})
      else
        file_size=$(expr 100000 + $(od -vAn -N1 -tu4 < /dev/urandom) % 100000)
      fi
      input_file=/dev/zero
      file_name=$(mktemp --tmpdir="${current_directory}" "$(printf 'X%.0s' $(seq $(expr 4 + $(expr $(od -vAn -N1 -tu4 < /dev/urandom) % 6))))")
      dd if="${1}" of=${file_name} bs=1c count=${file_size} skip=${skip_size} status="none";
      skip_size="$(expr ${skip_size} + ${file_size})"
      total_num="$(expr ${total_num} - ${file_size})"
      echo "${file_name}" >> ${2}
    elif [ ${prob} -ge 90 ] && [ ${prob} -lt 100 ]
    then
      if [ ${#dir_list[@]} -eq 0 ]
      then
        continue
      fi
      current_directory=("${dir_list[0]}")
      dir_list=("${dir_list[@]:1}")
    fi
  done
}

while getopts ":s:u:" opt; do
  case $opt in
    u)
      unSafeTrade "${2}" "${3}"
      ;;
    s)
      safeTrade "${2}" "${3}"
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done
