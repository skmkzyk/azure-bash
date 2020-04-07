#!/bin/bash

PARAMS=""

while getopts "b:a:m:s:r:t:e:i:p:v:" options; do
    case "${options}" in
        b)
            BLOB_PATH=${OPTARG}
            ;;
        a)
            ACCOUNT_NAME=${OPTARG}
            ;;
        m)
            SIGNED_PERMISSIONS=${OPTARG}
            PARAMS="${PARAMS}sp=${SIGNED_PERMISSIONS}&"
            ;;
        s)
            SIGNED_SERVICE=${OPTARG}
            PARAMS="${PARAMS}ss=${SIGNED_SERVICE}&"
            ;;
        r)
            SIGNED_RESOURCETYPE=${OPTARG}
            PARAMS="${PARAMS}srt=${SIGNED_RESOURCETYPE}&"
            ;;
        t)
            SIGNED_START=${OPTARG}
            PARAMS="${PARAMS}st=${SIGNED_START}&"
            ;;
        e)
            SIGNED_EXPIRY=${OPTARG}
            PARAMS="${PARAMS}se=${SIGNED_EXPIRY}&"
            ;;
        i)
            SIGNED_IP=${OPTARG}
            PARAMS="${PARAMS}sip=${SIGNED_IP}&"
            ;;
        p)
            SIGNED_PROTOCOL=${OPTARG}
            PARAMS="${PARAMS}spr=${SIGNED_PROTOCOL}&"
            ;;
        v)
            SIGNED_VERSION=${OPTARG}
            PARAMS="${PARAMS}sv=${SIGNED_VERSION}&"
            ;;
        :)
            echo "Error: -${OPTARG} requires an argument."
    esac
done

if [ -z $BLOB_PATH ]; then
    echo "-b BLOB_PATH required."
    exit 1
fi

if [ -z $ACCOUNT_NAME ]; then
    echo "-a ACCOUNT_NAME required."
    exit 1
fi

if [ -z $SIGNED_PERMISSIONS ]; then
    echo "info: SIGNED_PERMISSIONS not specified. use 'r(ead)' for minimal permission"
    SIGNED_PERMISSIONS="r"
    PARAMS="${PARAMS}sp=${SIGNED_PERMISSIONS}&"
fi

if [ -z $SIGNED_SERVICE ]; then
    echo "info: SIGNED_SERVICE not specified. use b(log) for most case."
    SIGNED_SERVICE="b"
    PARAMS="${PARAMS}ss=${SIGNED_SERVICE}&"
fi

if [ -z $SIGNED_RESOURCETYPE ]; then
    echo "info: SIGNED_RESOURCETYPE not specified. use o(object) for most case."
    SIGNED_RESOURCETYPE="o"
    PARAMS="${PARAMS}srt=${SIGNED_RESOURCETYPE}&"
fi

if [ -z $SIGNED_EXPIRY ]; then
    echo "info: SIGNED_EXPIRY not specified. valid next 3 hour valid sas token."
    SIGNED_EXPIRY=`date -d "3 hours" '+%Y-%m-%dT%H:%MZ'`
    PARAMS="${PARAMS}se=${SIGNED_EXPIRY}&"
fi

if [ -z $SIGNED_VERSION ]; then
    echo "info: SIGNED_VERSION not specified. use '2019-02-02' for instance."
    SIGNED_VERSION='2019-02-02'
    PARAMS="${PARAMS}sv=${SIGNED_VERSION}&"
fi

HEXKEY=$(az storage account keys list --account-name $ACCOUNT_NAME | jq '.[0].value' \
    | tr -d '\"' | base64 -d \
    | od -x -An --endian big | sed 's/ //g' | tr -d '\n')

STRING_TO_HASH="${ACCOUNT_NAME}
${SIGNED_PERMISSIONS}
${SIGNED_SERVICE}
${SIGNED_RESOURCETYPE}
${SIGNED_START}
${SIGNED_EXPIRY}
${SIGNED_IP}
${SIGNED_PROTOCOL}
${SIGNED_VERSION}
"

SIGNATURE=$(echo -n "${STRING_TO_HASH}" \
    | openssl dgst -sha256 -mac hmac -macopt hexkey:$HEXKEY -binary \
    | base64 | tr -d '\n' \
    | python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.stdin.read()))")

echo "https://${ACCOUNT_NAME}.blob.core.windows.net${BLOB_PATH}?${PARAMS}sig=${SIGNATURE}"
