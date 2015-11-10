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
  file_name=$(mktemp --tmpdir=${current_directory} "$(printf 'X%.0s' $(seq $(expr 4 + $(expr $(od -vAn -N1 -tu4 < /dev/urandom) % 6))))")
  dd if="${1}" of=${file_name} bs=1c count=${file_size} skip=${skip_size} status="none";
  skip_size="$(expr ${skip_size} + ${file_size})"
  total_num="$(expr ${total_num} - ${file_size})"
  echo "${file_name}" | cut -c ${directory_num}-${#file_name} >> ${2}
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

  output_directory="${2}/output"
  current_directory="${output_directory}/directory"
  directory_num=$((${#current_directory} + 2))
  block_name="${output_directory}/block"
  key_name="${output_directory}/key"
  crypt_name="${block_name}.gpg"
  mkdir ${output_directory} ${current_directory}

  MD5="\n${3}\n"
  for file in ${1}; do
    MD5="${MD5}$(stat -c%s "${file}")\n"
    MD5="${MD5}$(basename "${file}")\n"
    MD5="${MD5}$(md5sum ${file} | cut -d " " -f1)\n"
    cat "${file}" >> ${block_name}
  done

  gpg --passphrase ${3} -c --cipher-algo aes256 -o "${crypt_name}" "${block_name}"
  product_size=$(stat -c%s "${crypt_name}")

  skip_size=0
  total_num=5120000 #00
  dir_list=()

  for (( ; ; )); do

    prob=$(expr $(od -vAn -N1 -tu4 < /dev/urandom) % 100)
    if [ ${prob} -ge 0 ] && [ ${prob} -lt 10 ]; then
      createFolder
    elif [ ${prob} -ge 10 ] && [ ${prob} -lt 50 ]; then
      splitFile "${crypt_name}" "${key_name}"
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

  printf "${MD5}" >> ${key_name}

}

function unSafeTrade {

  output_directory="${2}/output_reverse"
  dir_name="${1}"
  block_name="${output_directory}/deblock"
  crypt_name="${block_name}.gpg"
  mkdir ${output_directory}

  decrypt=0
  size=0
  name=0
  verify=0
  skip_size=0
  while read -r file_name; do
    if (( ${verify} )); then
      echo "Verifying ${new_file}: ${md5} with ${file_name}"
      if [[ ${md5} = ${file_name} ]]; then
        echo "${new_file} was extracted with success"
      else
        echo "Error: ${new_file} corrupted"
        exit 1
      fi
      size=0
      name=0
      verify=0
    elif (( ${name} )); then
      echo "Creating ${file_name}"
      new_file="${output_directory}/${file_name}"
      mv "${output_directory}/unamed" ${new_file}
      md5=$(md5sum ${new_file}  | cut -d " " -f1)
      verify=1
    elif (( ${size} )); then
      echo "Catching ${skip_size} + ${file_name}"
      dd if=${block_name} of="${output_directory}/unamed" bs=1c count=${file_name} skip=${skip_size} status="none";
      skip_size="$(expr ${skip_size} + ${file_size})"
      name=1
    elif (( ${decrypt} )); then
      echo "Decrypting with passphrase ${file_name}"
      gpg --passphrase "${file_name}" -d -o ${block_name} ${crypt_name}
      size=1
    elif [[ ${file_name} = "" ]]; then
      echo "Empty line"
      decrypt=1
    else
      echo "Catning ${file_name}"
      cat "${dir_name}/${file_name}" >> ${crypt_name}
    fi
  done

}

reverse=0
while getopts "ui:o:p:" opt; do
  case $opt in
    u)
      #if [[ ${output_file} ]]; then
      #  echo "Reverse SafeTrade doesn't require output."
      #  exit 1
      #fi
      reverse=1
      ;;
    i)
      input_files=${OPTARG}
      ;;
    o)
      #if (( ${reverse}==1 )); then
      #  echo "Reverse SafeTrade doesn't require output."
      #  exit 1
      #fi
      output_file=${OPTARG}
      ;;
    p)
      passphrase=${OPTARG}
      ;;
  esac
done

#if [[ ${input_files} = "" ]]; then
#  read -p "Input Files: " -r input_files
#fi

#if [[ ${output_file} = "" ]]; then
#  read -p "Output Files: " -r output_file
#fi

if (( ${reverse} )); then
  unSafeTrade "${input_files}" "${output_file}"
else
  safeTrade "${input_files}" "${output_file}" "${passphrase}"
fi
