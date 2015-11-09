#!/bin/bash

function createFolder {
  dir_name=$(mktemp -d --tmpdir="${current_directory}" "$(printf 'X%.0s' $(seq $(expr 4 + $(expr $(od -vAn -N1 -tu4 < /dev/urandom) % 6))))")
  dir_list+=("${dir_name}")
  total_num="$(expr ${total_num} - 4000)"
}
function createFile {
  if [ $(expr ${total_num}) -le 204 ]; then
    file_size=${total_num}
  else
    file_size=$(expr 100 + $(od -vAn -N1 -tu4 < /dev/urandom) % 100)
  fi
  file_name=$(mktemp --tmpdir="${current_directory}" "$(printf 'X%.0s' $(seq $(expr 4 + $(expr $(od -vAn -N1 -tu4 < /dev/urandom) % 6))))")
  dd if=/dev/urandom of="${file_name}" bs=1K count=${file_size} status="none";
  total_num="$(expr ${total_num} - $(expr ${file_size} \* 1000 ) )"
}
function splitFile {
  if [ $(expr ${skip_size}) -ge $(expr ${product_size} - 204000) ]; then
    file_size=$(expr ${product_size} - ${skip_size})
  else
    file_size=$(expr 100000 + $(od -vAn -N1 -tu4 < /dev/urandom) % 100000)
  fi
  input_file=/dev/zero
  file_name=$(mktemp --tmpdir="${current_directory}" "$(printf 'X%.0s' $(seq $(expr 4 + $(expr $(od -vAn -N1 -tu4 < /dev/urandom) % 6))))")
  dd if="${1}" of="${file_name}" bs=1c count=${file_size} skip=${skip_size} status="none";
  skip_size="$(expr ${skip_size} + ${file_size})"
  total_num="$(expr ${total_num} - ${file_size})"
  echo "${file_name}" >> ${2}
}
function moveFolder {
  if [ ${#dir_list[@]} -eq 0 ]; then
    return
  fi
  current_directory=("${dir_list[0]}")
  dir_list=("${dir_list[@]:1}")
  dir_list+=("${current_directory}")
}

function safeTrade {

  crypt_name="${1}.gpg"
  gpg -c --cipher-algo aes256 -o "${crypt_name}" "${1}"

  for (( ; ; )); do

    prob=$(expr $(od -vAn -N1 -tu4 < /dev/urandom) % 100)
    if [ ${prob} -ge 0 ] && [ ${prob} -lt 10 ]; then
      createFolder
    elif [ ${prob} -ge 10 ] && [ ${prob} -lt 50 ]; then
      splitFile "${crypt_name}" "${2}"
    elif [ ${prob} -ge 50 ] && [ ${prob} -lt 100 ]; then
      moveFolder
    fi
    if [ $(expr ${skip_size}) -ge $(expr ${product_size}) ]; then
      break
    fi

  done

  for (( ; ; )); do

    prob=$(expr $(od -vAn -N1 -tu4 < /dev/urandom) % 100)
    if [ ${prob} -ge 0 ] && [ ${prob} -lt 10 ]; then
      createFolder
    elif [ ${prob} -ge 10 ] && [ ${prob} -lt 50 ]; then
      createFile
    elif [ ${prob} -ge 50 ] && [ ${prob} -lt 100 ]; then
      moveFolder
    fi
    if [ $(expr ${total_num}) -le 0 ]; then
      break
    fi

  done

}

function unSafeTrade {
  crypt_name="${2}.gpg"
  touch "${crypt_name}"
  for file_name in $(sed -n p "${1}")
  do
    cat "${file_name}" >> ${crypt_name}
  done
  gpg -d -o ${2} "${crypt_name}"
}

rm "${3}"
while getopts ":s:u:" opt; do
  case $opt in
    u)
      unSafeTrade "${2}" "${3}"
      ;;
    s)
      product_size=$(stat -c%s "${2}")
      skip_size=0
      total_num=5120000 #00
      current_directory="$(mktemp -d --tmpdir="/tmp/" "$(printf 'X%.0s' $(seq $(expr 4 + $(expr $(od -vAn -N1 -tu4 < /dev/urandom) % 6))))")"
      dir_list=()

      safeTrade "${2}" "${3}"
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done
