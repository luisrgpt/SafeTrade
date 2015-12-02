#!/bin/bash

function debugln {
  if (( ${debug} )); then
    echo "${1}"
  fi
}
function debug {
  if (( ${debug} )); then
    echo -n "${1} "
  fi
}
function randomProbabilityGenerator {
  prob=$(($(od -vAn -N2 -tu4 < /dev/urandom) % 1000))
}
function randomTemplateGenerator {
  random_template=$(printf 'X%.0s' $(seq $((4 + $(od -vAn -N1 -tu4 < /dev/urandom) % 6))))
}
function randomValueGenerator {
  random_value=$(($(od -vAn -N3 -tu4 < /dev/urandom) % 200000))
}
function createFolder {
  randomTemplateGenerator
  dir_name=$(mktemp -d --tmpdir="${current_directory}" ${random_template})
  dir_list+=("${dir_name}")
  total_num=$((${total_num} - 4000))
}
function createFile {
  if ((${total_num} <= 204000)); then
    file_size=${total_num}
  else
    randomValueGenerator
    file_size=${random_value}
  fi
  randomTemplateGenerator
  random_file=$(mktemp --tmpdir=${current_directory} ${random_template})
  dd if=/dev/urandom of=${random_file} bs=1c count=${file_size} status="none"
  selected_file=${random_file}
  file_list+=("${random_file}")
  total_num=$((${total_num} - ${file_size}))
  debugln "into ${random_file} (${random_value} bytes)"
}
function splitFile {
  debug "Spliting file "
  if ((${skip_size} >=  ${product_size} - 204000)); then
    file_size=$((${product_size} - ${skip_size}))
  else
    randomValueGenerator
    file_size=${random_value}
  fi
  randomTemplateGenerator
  random_file=$(mktemp --tmpdir=${current_directory} ${random_template})
  dd if="${1}" of=${random_file} bs=1c count=${file_size} skip=${skip_size} status="none"
  file_list+=("${random_file}")
  skip_size=$((${skip_size} + ${file_size}))
  total_num=$((${total_num} - ${file_size}))
  echo "${random_file}" | cut -c ${directory_num}-${#random_file} >> ${2}
  debugln "into ${random_file} (${random_value} bytes)"
}
function moveFolder {
  if ((${#dir_list[@]} == 0)); then
    return
  fi
  current_directory=("${dir_list[0]}")
  dir_list=("${dir_list[@]:1}")
  dir_list+=("${current_directory}")
}
function moveFile {
  if ((${#file_list[@]} == 0)); then
    return
  fi
  selected_file=("${file_list[0]}")
  file_list=("${file_list[@]:1}")
  file_list+=("${selected_file}")
}

function hideKeyKey {

   mypassword=($(md5sum ${safe_trade}))
   mypassword=${mypassword[0]}

   #file where to hide it (fazer isto melhor)
   fl=${image}
   #name of the new file (steg file)
   new_file="${output_directory}/image.jpg"
   touch /tmp/steg.bin
   # here it crypts the plaintext in cyphered text by aes25 and save it into steg.bin
   openssl aes-256-cbc -in ${1} -out /tmp/steg.bin -pass pass:"${mypassword}"
   # password length
   lenpw=$(expr length "$mypassword")
   lenpw_mod=$(echo 10 + 0 | bc)
   # temp1.bin is the head of the new file
   dd if=$fl of=/tmp/temp1.bin bs=1c count=$lenpw_mod status="none"
   # temp2.bin is a 10 bytes file filled of zeroes to store the secret message length
   dd if=$fl of=/tmp/temp2.bin bs=1c skip=$lenpw_mod count=10 status="none"
   # temp2.bin is the end of the new file
   dd if=$fl of=/tmp/temp3.bin bs=1c skip=$(echo $lenpw_mod + 10 | bc) status="none"
   dd if=/dev/zero of=/tmp/1temp2.bin count=10 bs=1c status="none"
   # hex conversion of steg.bin
   cat /tmp/steg.bin | xxd -p > /tmp/steghex.bin
   # len is the length of the steghex.bin file
   len=$(wc -c /tmp/steghex.bin|awk '{print $1 }')
   # hex conversion of len
   echo $len | xxd -p > /tmp/l.bin
   # it builts the new file
   cat /tmp/temp1.bin /tmp/l.bin /tmp/temp2.bin /tmp/steghex.bin /tmp/temp3.bin > ${new_file}
   rm /tmp/temp1.bin /tmp/temp2.bin /tmp/temp3.bin /tmp/steg.bin /tmp/steghex.bin /tmp/l.bin #${1}

}

function unhideKeyKey {
   #file containing the key
   file=${image}

   # ainda nao sei como gerar esta password
   mypassword=($(md5sum ${safe_trade}))
   mypassword=${mypassword[0]}

   lenpw=$(expr length "$mypassword")
   lenpw_mod=$(echo 0 + 10 | bc)
   len=$(dd if=$file skip=$lenpw_mod bs=1c count=10 status="none" | xxd -r -p)
   # it finds the openssl aes256 signanture into the target file and it takes the offset
   sk=$(grep -iaob -m 1 "53616c746564" $file | awk -F ":" '{print $1}')
   dd if=$file bs=1c skip=$sk count=$len status="none" | xxd -r -p | openssl aes-256-cbc -d -out ${1} -pass pass:"${mypassword}"
}

function getBlock {
  debugln "Concatenating files from ${1} into block ${2}"
  if [[ -d "${1}" ]]; then
    files=()
    shopt -s lastpipe
    find "${1}" -type f -name '*' -print0 | while IFS= read -r -d '' file; do
      files+=("${file}")
    done
  else
    files=("${1}")
  fi
  for file in "${files[@]}"; do
    if [[ -d "${file}" ]]; then
      continue
    fi
    debugln "Checking file ${file}"
    MD5="${MD5}$(stat -c%s "${file}")\n"
    MD5="${MD5}$(echo "${file}" | cut -c 1-${#file})\n"
    MD5="${MD5}$(md5sum "${file}" | cut -d " " -f1)\n"
    cat "${file}" >> ${2}
  done
  debugln "Concatenated files from ${1} into block ${2}"
}

function getEncriptedBlock {
  debug "Encrypting ${1} using passphrase ${2} into ${3}..."
  openssl aes-256-ecb -in "${1}" -out ${3} -pass pass:"${2}"
  product_size=$(stat -c%s "${3}")
  rm ${1}
  debugln "Done"
}

function generateFolderSystem {
  debugln "Injecting encrypted block ${1} into ${2} and creating key ${3}"
  dir_list=()
  file_list=()
  skip_size=0
  current_directory="${2}"
  directory_num=$((${#2} + 1))
  for (( ; ; )); do
    randomProbabilityGenerator
    if [ ${prob} -ge 0 ] && [ ${prob} -lt 10 ]; then
      createFolder
    elif [ ${prob} -ge 10 ] && [ ${prob} -lt 50 ]; then
      splitFile "${1}" "${3}"
      debugln "${total_num}"
    elif [ ${prob} -ge 50 ] && [ ${prob} -lt 1000 ]; then
      moveFolder
    fi
    if ((${skip_size} >= ${product_size})); then
      break
    fi
  done
  debugln "Injected encrypted block"
  debugln "Completing folder system in ${2}"
  for (( ; ; )); do
    randomProbabilityGenerator
    if [ ${prob} -ge 0 ] && [ ${prob} -lt 1 ]; then
      createFolder
    elif [ ${prob} -ge 1 ] && [ ${prob} -lt 50 ]; then
      debugln "${total_num}"
      createFile
    elif [ ${prob} -ge 50 ] && [ ${prob} -lt 1000 ]; then
      moveFolder
    fi
    if ((${total_num} <= 0)); then
      break
    fi
  done
  printf "${MD5}" >> ${3}
  rm ${1}
  debugln "Completed folder system"
}

function hideKey {
  debugln "Injecting key ${1} into ${2} and creating secondary key ${3}"
  current_directory="${2}"
  for (( ; ; )); do
    randomProbabilityGenerator
    if [ ${prob} -ge 0 ] && [ ${prob} -lt 1 ]; then
      debug "Encrypting key with ${selected_file} hash "
      randomTemplateGenerator
      random_file=$(mktemp --tmpdir=${current_directory} ${random_template})
      debugln "into ${random_file}"
      gpg -q --yes --passphrase "$(md5sum ${selected_file})" -c --cipher-algo aes256 -o ${random_file} ${1}
      break
    elif [ ${prob} -ge 1 ] && [ ${prob} -lt 1000 ]; then
      moveFile
    fi
  done
  keykey=${selected_file}
  for (( ; ; )); do
    randomProbabilityGenerator
    if [ ${prob} -ge 0 ] && [ ${prob} -lt 1 ]; then
      debugln "Moving key key into $(dirname ${selected_file})"
      mv ${random_file} $(dirname ${selected_file})
      break
    elif [ ${prob} -ge 1 ] && [ ${prob} -lt 1000 ]; then
      moveFile
    fi
  done
  keykey="${keykey}\n$(dirname ${selected_file})/$(basename ${random_file})\n"
  printf "${keykey}" >> ${3}
  rm ${1}
  debugln "Injected key ${1}"
}

function unhideKey {
  debugln "Extracting key ${2} using secondary key ${1}"
  verify=0
  while read -r line; do
    if (( ${verify} )); then
      debugln "Decrypting key ${line} with ${random_file} hash into ${2}"
      gpg -q --yes --passphrase "$(md5sum ${random_file})" -d -o ${2} ${line}
    else
      debugln "Found random file ${line}"
      random_file=${line}
      verify=1
    fi
  done < ${1}
  rm ${1}
  debugln "Extracted key ${2}"
}

function unhideFiles {
  debugln "Extracting files from ${4} using key ${1} into ${5}"
  decrypt=0
  size=0
  name=0
  verify=0
  skip_size=0
  while read -r line; do
    if (( ${verify} )); then
      if [[ ${md5} = ${line} ]]; then
        echo "${new_file} was extracted with success"
      else
        echo "Warning: ${new_file} corrupted"
      fi
      name=0
      verify=0
    elif (( ${name} )); then
      debug "to $(basename "${line}")..."
      mkdir -p "${5}/$(dirname "${line}")"
      new_file="${5}/${line}"
      mv "${5}/unamed" "${new_file}"
      md5=$(md5sum "${new_file}"  | cut -d " " -f1)
      verify=1
      debugln "Done"
    elif (( ${size} )); then
      debug "Extracting ${line} bytes"
      dd if=${3} of="${5}/unamed" bs=1c count=${line} skip=${skip_size} status="none";
      skip_size=$((${skip_size} + ${line}))
      name=1
    elif (( ${decrypt} )); then
      debug "Decrypting ${2} using passphrase ${line} into ${3}..."
      openssl aes-256-ecb -d -in "${2}" -out "${3}" -pass pass:"${line}"
      size=1
      debugln "Done"
    elif [[ ${line} = "" ]]; then
      debugln "Concatenation completed"
      decrypt=1
    else
      debug "Joining ${4}/${line} into ${2}..."
      cat "${4}/${line}" >> ${2}
      debugln "Done"
    fi
  done < ${1}
  rm ${1} ${2} ${3}
  debugln "Extracted all files"
}

prob=0
safe_trade="${0}"
reverse=0
debug=0
force=0
while getopts "hdui:o:p:k:s:" opt; do
  case $opt in
    h)
      echo "SafeTrade flags:"
      echo " -h : Help"
      echo " -d : Debug mode"
      echo " -u : Show hidden files"
      echo " -i : Input file or directory location"
      echo " -o : Output directory location"
      echo " -p : Passphrase for encryption (to hide files only)"
      echo " -k : Key image (to show hidden files only)"
      echo " -s : Aproximate folder system size in MB (to hide files only)"
      exit 1
      ;;
    d)
      debug=1
      ;;
    f)
      force=1
      ;;
    u)
      reverse=1
      ;;
    i)
      input_directory="$(echo ${OPTARG})"
      ;;
    o)
      output_directory="$(echo ${OPTARG})"
      ;;
    p)
      if (( ${reverse} )); then
        echo "Showing hidden files doesn't require a passphrase"
        echo "Exiting SafeTrade"
        exit 1
      fi
      passphrase="${OPTARG}"
      ;;
    k)
      image="$(echo ${OPTARG})"
      ;;
    s)
      if (( ${reverse} )); then
        echo "Showing hidden files doesn't require a folder system size"
        echo "Exiting SafeTrade"
        exit 1
      fi
      size="${OPTARG}"
      ;;
  esac
done

if ! [[ "${input_directory}" ]]; then
  read -p "Input Files [input/]: " -r input_directory
  input_directory=${input_directory:-input}
  input_directory="$(echo ${input_directory})"
fi
if ! [[ -d "${input_directory}" ]]; then
  while ! [[ ${input_directory} ]]; do
    read -p "Input files: " -r input_directory
  done
fi
if ! [[ "${output_directory}" ]]; then
  read -p "Output Directory [output/]: " -r output_directory
  output_directory=${output_directory:-output}
  output_directory="$(echo ${output_directory})"
fi
if [[ -d "${output_directory}" ]]; then
  echo "Output directory already exists"
  echo "Exiting SafeTrade"
  exit 1
fi
mkdir -p ${output_directory}

if ! (( ${reverse} )) && ! [[ "${passphrase}" ]]; then
  while ! [[ ${passphrase} ]]; do
    read -p "Passphrase: " -r passphrase
  done
fi
if ! [[ "${image}" ]]; then
  while ! [[ ${image} ]]; do
    read -p "Image: " -r image
    image="$(echo ${image})"
  done
fi
if ! (( ${reverse} )); then
  if ! [[ ${size} ]]; then
    read -p "Folder system size in MB [5]: " -r size
    size=${size:-5}
  fi
  total_num=$((${size} * 1024000))
fi
if (($(stat -c%s "${input_directory}") >= ${total_num})); then
  echo "SafeTrade requires a bigger folder system size:  (Input size) $(stat -c%s "${input_directory}") >= (Folder system size) ${total_num}"
  exit 1
fi

if (( ${reverse} )); then
  randomTemplateGenerator
  keykey_name=$(mktemp --tmpdir=/tmp/ ${random_template})
  unhideKeyKey "${keykey_name}"

  randomTemplateGenerator
  key_name=$(mktemp --tmpdir=/tmp/ ${random_template})
  unhideKey "${keykey_name}" "${key_name}"

  randomTemplateGenerator
  crypt_name=$(mktemp --tmpdir=/tmp/ ${random_template})
  randomTemplateGenerator
  block_name=$(mktemp --tmpdir=/tmp/ ${random_template})
  unhideFiles "${key_name}" "${crypt_name}" "${block_name}" "${input_directory}" "${output_directory}"
else
  MD5="\n${passphrase}\n"

  randomTemplateGenerator
  block_name=$(mktemp --tmpdir=/tmp/ ${random_template})
  getBlock "${input_directory}" "${block_name}"

  randomTemplateGenerator
  crypt_name=$(mktemp --tmpdir=/tmp/ ${random_template})
  getEncriptedBlock "${block_name}" "${passphrase}" "${crypt_name}"

  randomTemplateGenerator
  key_name=$(mktemp --tmpdir=/tmp/ ${random_template})
  generateFolderSystem "${crypt_name}" "${output_directory}" "${key_name}"

  randomTemplateGenerator
  keykey_name=$(mktemp --tmpdir=/tmp/ ${random_template})
  hideKey "${key_name}" "${output_directory}" "${keykey_name}"

  hideKeyKey "${keykey_name}"
fi
