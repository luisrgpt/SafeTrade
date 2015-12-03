# SafeTrade
## Requirements
- Unix-like Operative System
- Bash and built-in commands
- openSSL
- md5sum
- mktemp

## Usage
To hide information
>safeTrade.sh -i input_file_or_folder -o  output_folder -p passphrase -s #folder_system_size -k image

To retrieve information
>safeTrade.sh -u -i input_folder -o  output_folder -k image

Note: All flags and arguments are optional. SafeTrade shall ask for them instead
