#!/bin/bash

#
# ascp download from shares
#
# Broad Institute, BITS
#
# Fragment borrowed from ascp-shares.sh Authored by Aspera
#

DBG=true
DBG=false

#
# Internals
#

_usage() {
  echo " To decrypt files, please set the  ASPERA_SCP_FILEPASS environemnt variable."
  echo
  echo "  Usage: $0 LOCAL_TARGET SHARES_URL USER:PASSWORD /SHARES/PATH/TO/SOURCE/FILE"
  echo
  echo "  Example: ascp-shares-down.sh /home/user/me/my_aspera_downloads https://shares.broadinstitute.org SN0000000:ABCD1234efgh /SN00000000/foo.bar"
  echo
  exit 1
}

_prep() {
  case "`uname`" in
Darwin*)
  MKTEMP="mktemp -t tmp" ;;
*)
  MKTEMP=mktemp
  esac
}
  
_get_response_from_json() {
  JSON=\{\"transfer_requests\":\[\{\"transfer_request\":\{\"paths\":\[\{\"source\":\"$SHARES_SOURCE\"\}\]\}\}\]\}
  JSONFILE=`$MKTEMP`
  echo $JSON > $JSONFILE
  
  if ($DBG) 
  then
    echo "--------------------------"
    echo
    echo JSON:
    echo
    echo `cat $JSONFILE`
    echo
  fi
  
  RESPONSE=`curl -ki -sS -H "Accept: application/json" -H "Content-type: application/json" -u $USERPASS -X POST -d @$JSONFILE $URL_DOWNLOAD_SETUP`
  rm $JSONFILE

  if ($DBG)
  then
    echo "--------------------------"
    echo
    echo RESPONSE: 
    echo
    echo "$RESPONSE"
    echo
  fi

}

_download_setup() {
_get_response_from_json


  TOKEN=`echo $RESPONSE | sed 's/\\\\\//\//g' | sed 's/[{}]//g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}'   | sed 's/\"//g' | grep -w token | cut -d: -f2`
  SOURCE=`echo $RESPONSE | sed 's/\\\\\//\//g' | sed 's/[{}]//g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}'   | sed 's/\"//g' | grep -w source | cut -d: -f8 | sed 's/\]//g'`
  USER=`echo $RESPONSE | sed 's/\\\\\//\//g' | sed 's/[{}]//g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}'   | sed 's/\"//g' | grep -w remote_user | cut -d: -f2`
  HOST=`echo $RESPONSE | sed 's/\\\\\//\//g' | sed 's/[{}]//g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}'   | sed 's/\"//g' | grep -w remote_host | cut -d: -f2`

  if ($DBG)
  then
    echo "--------------------------"
    echo
    echo VALUES FROM RESPONSE: 
    echo TOKEN: $TOKEN
    echo SOURCE: $SOURCE
    echo USER: $USER
    echo HOST: $HOST
    echo
  fi


}

_temp_key_make() {
  KEY=`$MKTEMP`
    echo "-----BEGIN DSA PRIVATE KEY-----
MIIBuwIBAAKBgQDkKQHD6m4yIxgjsey6Pny46acZXERsJHy54p/BqXIyYkVOAkEp
KgvT3qTTNmykWWw4ovOP1+Di1c/2FpYcllcTphkWcS8lA7j012mUEecXavXjPPG0
i3t5vtB8xLy33kQ3e9v9/Lwh0xcRfua0d5UfFwopBIAXvJAr3B6raps8+QIVALws
yeqsx3EolCaCVXJf+61ceJppAoGAPoPtEP4yzHG2XtcxCfXab4u9zE6wPz4ePJt0
UTn3fUvnQmJT7i0KVCRr3g2H2OZMWF12y0jUq8QBuZ2so3CHee7W1VmAdbN7Fxc+
cyV9nE6zURqAaPyt2bE+rgM1pP6LQUYxgD3xKdv1ZG+kDIDEf6U3onjcKbmA6ckx
T6GavoACgYEAobapDv5p2foH+cG5K07sIFD9r0RD7uKJnlqjYAXzFc8U76wXKgu6
WXup2ac0Co+RnZp7Hsa9G+E+iJ6poI9pOR08XTdPly4yDULNST4PwlfrbSFT9FVh
zkWfpOvAUc8fkQAhZqv/PE6VhFQ8w03Z8GpqXx7b3NvBR+EfIx368KoCFEyfl0vH
Ta7g6mGwIMXrdTQQ8fZs
-----END DSA PRIVATE KEY-----
" > $KEY
    }

_download() {
  
_temp_key_make

if [ -z ${ASPERA_SCP_FILEPASS}"" ]; then
  echo "No ASPERA_SCP_FILEPASS environment variable found. Downloading without decryption"
  CMD="ascp --ignore-host-key -k 1 -Ql100m -d -i $KEY -W $TOKEN -P 33001 $USER@$HOST:$SOURCE $TARGET"
else
  # change the paths
  echo "ASPERA_SCP_FILEPASS environment variable found. Decrypting and downloading"
  CMD="ascp --ignore-host-key --file-manifest=text --file-manifest-path=/ifs/labs/cccb/projects/cccb/projects/Crowley/LP_06092017_1322/broad_bams -L /ifs/labs/cccb/pro\
jects/cccb/projects/Crowley/LP_06092017_1322/broad_bams/logs -k 1 -Ql100m -d --file-crypt=decrypt -i $KEY -W $TOKEN -P 33001 $USER@$HOST:$SOURCE $TARGET"
fi

if($DBG)
  then
    echo $CMD
  fi

  echo $CMD
  eval $CMD
  #echo $CMD
  #cat $KEY
  rm $KEY
}

#
# Main program
#

if test $# -lt 4; then
  _usage
fi

TARGET=$1
URL_DOWNLOAD_SETUP=$2/node_api/files/download_setup
USERPASS=$3
SHARES_SOURCE=$4


_prep
_download_setup
_download
