#!/bin/bash

while getopts "a:f:t:e:" options; do
    case "${options}" in
        a)
            ACCOUNT_NAME=${OPTARG}
            ;;
        f)
            FROM_CONTAINER=${OPTARG}
            ;;
        t)
            TO_CONTAINER=${OPTARG}
            ;;
        e)
            EXPIRY=${OPTARG}
            ;;
        :)
            echo "Error: -${OPTARG} requires an argument." >&2
            exit 1
    esac
done

if [ -z $ACCOUNT_NAME ]; then
    echo "-a ACCOUNT_NAME required." >&2
    exit 1
fi

if [ -z $FROM_CONTAINER ]; then
    echo "-f FROM_CONTAINER required." >&2
    exit 1
fi

if [ -z $TO_CONTAINER ]; then
    echo "-t TO_CONTAINER required." >&2
    exit 1
fi

if [ -z $EXPIRY ]; then
    EXPIRY=`date -d "3 hours" '+%Y-%m-%dT%H:%MZ'`
    echo "info: EXPIRY not specified. automatically generate sas token valid next 3 hour. (${EXPIRY})" >&2
fi

export AZURE_STORAGE_KEY=$(az storage account keys list --account-name $ACCOUNT_NAME | jq '.[0].value' | tr -d '\"')
echo "info: expoted AZURE_STORAGE_KEY to environment variable" >&2

container_sas=$(az storage account generate-sas --permissions "l" --account-name $ACCOUNT_NAME --services "b" --resource-types "c" --expiry ${EXPIRY} -o tsv)

for file in $(curl -s "https://${ACCOUNT_NAME}.blob.core.windows.net/${FROM_CONTAINER}?restype=container&comp=list&${container_sas}" \
    | sed 's/></>\n</g' | grep "<Name>" | sed 's/<Name>\([^<]*\)<\/Name>/\1/g'); do

    src=$(az storage blob generate-sas --permissions r \
        --container-name ${FROM_CONTAINER} --name $file \
        --expiry ${EXPIRY} --account-name $ACCOUNT_NAME --full-uri \
        | tr -d '\"')

    dst=$(az storage blob generate-sas --permissions w \
        --container-name ${TO_CONTAINER} --name $file \
        --expiry ${EXPIRY} --account-name $ACCOUNT_NAME --full-uri \
        | tr -d '\"')

    curl -X PUT \
        -H "Content-Length: 0" \
        -H "x-ms-requires-sync: true" \
        -H "x-ms-copy-source: $src" \
        $dst
    echo "info: copy blob from URL executed for file: $file" >&2
done