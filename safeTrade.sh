#!/bin/bash

function debugln {
  if (( ${debug} )); then
    echo "${1}"
  fi
}
function debug {
  if (( ${debug} )); then
    echo -n "${1}"
  fi
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
  dd if=/dev/urandom of=${random_file} bs=1c count=${file_size} status="none";
  selected_file=${random_file}
  file_list+=("${random_file}")
  total_num=$((${total_num} - ${file_size}))
  debugln "into ${random_file} (${random_value} bytes)"
}
function splitFile {
  if ((${skip_size} >=  ${product_size} - 204000)); then
    file_size=$((${product_size} - ${skip_size}))
  else
    randomValueGenerator
    file_size=${random_value}
  fi
  randomTemplateGenerator
  random_file=$(mktemp --tmpdir=${current_directory} ${random_template})
  dd if="${1}" of=${random_file} bs=1c count=${file_size} skip=${skip_size} status="none";
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

function hide {
	
   # ainda nao deecidi como gerar esta password
   mypassword = 123456789
	
   #key to hide
   ms = $key_name
   echo $ms>/tmp/ptext
   #file where to hide it (fazer isto melhor)
   fl = ./dog.jpg
   #name of the new file (steg file)
   new_file = myfluffydog.jpg
   # here it crypts the plaintext in cyphered text by aes25 and save it into steg.bin
   openssl aes-256-cbc -in /tmp/ptext -out /tmp/steg.bin -k mypassword
   # password length
   lenpw=$(expr length "$mypassword")
   lenpw_mod=$(echo 10 + 0 | bc)
   # temp1.bin is the head of the new file
   dd if=$fl of=/tmp/temp1.bin bs=1c count=$lenpw_mod
   # temp2.bin is a 10 bytes file filled of zeroes to store the secret message length 
   dd if=$fl of=/tmp/temp2.bin bs=1c skip=$lenpw_mod count=10
   # temp2.bin is the end of the new file
   dd if=$fl of=/tmp/temp3.bin bs=1c skip=$(echo $lenpw_mod + 10 | bc)
   dd if=/dev/zero of=/tmp/1temp2.bin count=10 bs=1c
   # hex conversion of steg.bin 
   cat /tmp/steg.bin | xxd -p > /tmp/steghex.bin
   # len is the length of the steghex.bin file
   len=$(wc -c /tmp/steghex.bin|awk '{print $1 }')
   # hex conversion of len
   echo $len | xxd -p > /tmp/l.bin
   # it builts the new file
   cat /tmp/temp1.bin /tmp/l.bin /tmp/temp2.bin /tmp/steghex.bin /tmp/temp3.bin > $nfl
   srm /tmp/temp1.bin /tmp/temp2.bin /tmp/temp3.bin /tmp/steg.bin /tmp/steghex.bin /tmp/ptext /tmp/l.bin
   
}

function unhide {
   #file containing the key
   file = ./myfluffydog.jpg

   # ainda nao sei como gerar esta password
   mypassword = 123456789

   lenpw=$(expr length "$mypassword")
   lenpw_mod=$(echo 0 + 10 | bc)
   len=$(dd if=$file skip=$lenpw_mod bs=1c count=10 | xxd -r -p)
   # it finds the openssl aes256 signanture into the target file and it takes the offset 
   sk=$(grep -iaob -m 1 "53616c746564" $file | awk -F ":" '{print $1}')
   dd if=$file bs=1c skip=$sk count=$len status=noxfer | xxd -r -p | openssl aes-256-cbc -d -out text.txt -k $mypassword
   cat text.txt
   key = echo text.txt
   #srm text.txt
}


function safeTrade {
  output_directory="${2}"
  current_directory=${output_directory}
  directory_num=$((${#current_directory} + 2))
  block_name="${output_directory}/block"
  key_name="${output_directory}/key"
  crypt_name="${block_name}.gpg"
  mkdir -p ${output_directory} ${current_directory}

  MD5="\n${3}\n"

  FILES=$(ls -RA ${1} | awk '/:$/&&f{s=$0;f=0}/:$/&&!f{sub(/:$/,"");s=$0;f=1;next}NF&&f{ print s"/"$0 }')

  for file in ${FILES}; do
    if [[ -d "${file}" ]]; then
      continue
    fi
    debugln "Checking file ${file}"
    MD5="${MD5}$(stat -c%s "${file}")\n"
    MD5="${MD5}$(echo "${file}" | cut -c 1-${#file})\n"
    MD5="${MD5}$(md5sum ${file} | cut -d " " -f1)\n"
    cat "${file}" >> ${block_name}
  done

  debugln "Encrypting ${block_name} using passphrase ${3} into ${crypt_name}"
  gpg -q --passphrase ${3} -c --cipher-algo aes256 -o ${crypt_name} ${block_name}
  product_size=$(stat -c%s "${crypt_name}")

  skip_size=0
  total_num=$((${size} * 1024000)) #00
  if (($(stat -c%s "${crypt_name}") >= ${total_num} + 204000)); then
    echo "SafeTrade requires a bigger folder system size"
    exit 1
  fi
  dir_list=()
  file_list=()

  for (( ; ; )); do
    debugln "${total_num}"
    prob=$(expr $(od -vAn -N1 -tu4 < /dev/urandom) % 100)
    if [ ${prob} -ge 0 ] && [ ${prob} -lt 10 ]; then
      debugln "Creating folder"
      createFolder
    elif [ ${prob} -ge 10 ] && [ ${prob} -lt 50 ]; then
      debug "Spliting file "
      splitFile "${crypt_name}" "${key_name}"
    elif [ ${prob} -ge 50 ] && [ ${prob} -lt 100 ]; then
      debugln "Moving folder"
      moveFolder
    fi
    if ((${skip_size} >= ${product_size})); then
      debugln "Injected all files"
      break
    fi
  done

  for (( ; ; )); do
    debugln "${total_num}"
    prob=$(expr $(od -vAn -N1 -tu4 < /dev/urandom) % 100)
    if [ ${prob} -ge 0 ] && [ ${prob} -lt 10 ]; then
      debugln "Creating folder"
      createFolder
    elif [ ${prob} -ge 10 ] && [ ${prob} -lt 50 ]; then
      debug "Creating file"
      createFile
    elif [ ${prob} -ge 50 ] && [ ${prob} -lt 100 ]; then
      debugln "Moving folder"
      moveFolder
    fi
    if ((${total_num} <= 0)); then
      debugln "Completed folder system"
      break
    fi
  done

  printf "${MD5}" >> ${key_name}

  for (( ; ; )); do
    debugln "${total_num}"
    prob=$(expr $(od -vAn -N1 -tu4 < /dev/urandom) % 100)
    if [ ${prob} -ge 0 ] && [ ${prob} -lt 1 ]; then
      debugln "Encrypting key with ${selected_file} hash"
      randomTemplateGenerator
      random_file=$(mktemp --tmpdir=${current_directory} ${random_template})
      gpg -q --passphrase "$(md5sum ${selected_file})" -c --cipher-algo aes256 -o ${random_file} ${key_name}
      break
    elif [ ${prob} -ge 1 ] && [ ${prob} -lt 100 ]; then
      moveFile
      break
    fi
  done

  keykey=${selected_file}

  for (( ; ; )); do
    debugln "${total_num}"
    prob=$(expr $(od -vAn -N1 -tu4 < /dev/urandom) % 100)
    if [ ${prob} -ge 0 ] && [ ${prob} -lt 1 ]; then
      debugln "Moving key key into $(dirname ${selected_file})"
      mv ${random_file} $(dirname ${selected_file})
      break
    elif [ ${prob} -ge 1 ] && [ ${prob} -lt 100 ]; then
      moveFile
      break
    fi
  done

  keykey="${keykey}\n$(dirname ${selected_file})/$(basename ${random_file})"

  printf "${keykey}" >> "${key_name}.txt"
  gpg -q --passphrase "$(md5sum ${safe_trade})" -c --cipher-algo aes256 -o "${key_name}1.txt" "${key_name}.txt"

  zip "${key_name}.zip" "${key_name}1.txt"
  cat ${image} "${key_name}.zip" > ${image}.safe

  rm ${block_name} ${crypt_name} ${key_name} "${key_name}.txt" "${key_name}1.txt" "${key_name}.zip"

}
function unSafeTrade {

  block_name="${output_directory}/deblock"
  crypt_name="${block_name}.gpg"
  mkdir -p ${output_directory}

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
        echo "Error: ${new_file} corrupted"
        exit 1
      fi
      name=0
      verify=0
    elif (( ${name} )); then
      debugln "to $(basename ${line})"
      mkdir -p "${output_directory}/$(dirname ${line})"
      new_file="${output_directory}/${line}"
      mv "${output_directory}/unamed" ${new_file}
      md5=$(md5sum ${new_file}  | cut -d " " -f1)
      verify=1
    elif (( ${size} )); then
      debug "Extracting ${line} bytes "
      dd if=${block_name} of="${output_directory}/unamed" bs=1c count=${line} skip=${skip_size} status="none";
      skip_size="$(expr ${skip_size} + ${line})"
      name=1
    elif (( ${decrypt} )); then
      debugln "Decrypting ${crypt_name} using passphrase ${line} into ${block_name}"
      gpg -q --passphrase "${line}" -d -o ${block_name} ${crypt_name}
      size=1
    elif [[ ${line} = "" ]]; then
      debugln "Concatenation completed"
      decrypt=1
    else
      debugln "Joining ${input_directory}/${line} into ${crypt_name}"
      cat "${input_directory}/${line}" >> ${crypt_name}
    fi
  done < "${input_directory}/key"

  rm ${block_name} ${crypt_name}

}

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
      input_directory="${OPTARG}"
      ;;
    o)
      output_directory="${OPTARG}"
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
      image="${OPTARG}"
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

if ! [[ ${input_directory} ]]; then
  read -p "Input Files [input/]: " -r input_directory
  input_directory=${input_directory:-input}
fi
if ! [[ -d ${input_directory} ]]; then
  while ! [[ ${input_directory} ]]; do
    read -p "Input files: " -r input_directory
  done
fi
if ! [[ ${output_directory} ]]; then
  read -p "Output Directory [output/]: " -r output_directory
  output_directory=${output_directory:-output}
fi
if [[ -d ${output_directory} ]]; then
  echo "Output directory already exists"
  echo "Exiting SafeTrade"
  exit 1
fi
if ! (( ${reverse} )) && ! [[ ${passphrase} ]]; then
  while ! [[ ${passphrase} ]]; do
    read -p "Passphrase: " -r passphrase
  done
fi
if ! [[ ${image} ]]; then
  while ! [[ ${image} ]]; do
    read -p "Image: " -r image
  done
fi
if ! (( ${reverse} )) && ! [[ ${size} ]]; then
  read -p "Folder system size in MB [5]: " -r size
  size=${size:-5}
fi

if (( ${reverse} )); then
  unhide
  unSafeTrade
else
  safeTrade "${input_directory}" "${output_directory}" "${passphrase}"
  hide
fi
