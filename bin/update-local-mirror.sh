#!/usr/bin/env bash
################################################################################
#  DESCRIPTION: This file will download all the file_url's defined in
#               snort-local-mirror.conf and prepare them for use as a local
#               rules mirror
#
#               This mirror requires a properly configured web server and pp
#               needs to be pointed to the local mirror in pulledpork.conf
################################################################################
set -o xtrace
set -o errexit
set -o nounset

# init
PP_CONFIG="/usr/local/etc/snort/pulledpork-mirror.conf"
WWW_DIR="/usr/local/lib/snort/www"

# This script doesn't create this directory; use some sort of devops config
# management tool to do that (e.g. Ansible, Puppet, Chef)
if [[ ! -d "${WWW_DIR}" ]]; then
    echo "Mirror hosting dir [${WWW_DIR}] needs to exist before this script runs. Exiting..."
    exit 1
fi

# Get urls to be mirrored
FILE_URLS=$( grep '^ *rule_url' "${PP_CONFIG}" | awk -F'=' '{print $NF}' )
# This version string capture is based on how pulledpork actually gets the snort
# version
SNORT_VERSION="$( snort -V 2>&1 | grep Version | awk '{ for (i=1;i<NF;i++) if ( $i ~ /[0-9]\.[0-9]\.[0-9]\.[0-9]/ ) { print $i } }' | sed 's/\.//g' )"

for URL_DETAILS in ${FILE_URLS}; do
    # I originally used "read a b c <<<$(...)" to do this but my vi syntax
    # highlighting barfed on that; so I changed it to a more straightforward
    # mechanism
    URL=$(  echo "${URL_DETAILS}" | awk -F'|' '{print $1}' )
    FILE=$( echo "${URL_DETAILS}" | awk -F'|' '{print $2}' )
    OINK=$( echo "${URL_DETAILS}" | awk -F'|' '{print $3}' )
    DEST="${WWW_DIR}/${FILE}"

    if [[ "${OINK}" == "open" || "${OINK}" == "Community" ]] ; then
        OINK=""
    else
        OINK="/${OINK}"
    fi

    # This if..then branch is based on similar branching found in pulledpork.pl
    if [[ "${FILE}" == "snortrules-snapshot.tar.gz" ]] ; then
        FILE="$( basename "${FILE}" .tar.gz )-${SNORT_VERSION}.tar.gz"
    elif [[ "${FILE}" == "IPBLACKLIST" ]] ; then
        DEST="${WWW_DIR}/$( echo "${URL}" | awk -F'/' '{print $NF}' )"
        FILE=""
    fi

    FILE_URL="${URL}${FILE}${OINK}"
    MD5_FILE_URL="${URL}/${FILE}.md5${OINK}"
    # WARNING! Downloading too frequently will put the IP address one is
    # downloading from on the "abuse" list; snort.org will block downloads for
    # an hour! "too frequent" is "more than once per second", so 5 sec sleep
    # is good enough to prevent this problem
    curl -L -k -s -o"${DEST}" "${FILE_URL}"
    sleep 5
    curl -L -k -s -o"${DEST}.md5" "${MD5_FILE_URL}"
    sleep 5
done
