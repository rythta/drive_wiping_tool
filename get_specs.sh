#!/bin/bash
SMART_RAW="$(smartctl -i $1)"
SG_RAW="$(sg_readcap $1)"

FAMILY="$(echo "${SMART_RAW}" | grep -E 'Family|Vendor' | awk -F': ' '{print $2}' | tail -1 | awk '{$1=$1};1')"
MODEL="$(echo "${SMART_RAW}" | grep -E 'Model|Product' | awk -F': ' '{print $2}' | tail -1 | awk '{$1=$1};1')"
SERIAL="$(echo "${SMART_RAW}" | grep 'Serial' | awk -F': ' '{print $2}' | tail -1 | awk '{$1=$1};1')"
RPM="$(echo "${SMART_RAW}" | grep -i 'rpm' | awk -F': ' '{print $2}' | tail -1 | awk '{$1=$1};1')"
FF="$(echo "${SMART_RAW}" | grep -i 'inches' | awk -F': ' '{print $2}' | tail -1 | awk '{$1=$1};1')"
SS="$(echo "${SG_RAW}" | grep -oE '512 bytes|520 bytes')"
INTERFACE="$(echo "${SMART_RAW}" | grep -E 'SATA|SAS' | awk -F': ' '{print $2}' | tail -1 | awk '{$1=$1};1' | sed 's/,.*//g')"
GB="$(echo "${SG_RAW}" | grep -oE '\d+.\d+ GB')"
TB="$(echo "${SG_RAW}" | grep -oE '\d+.\d+ TB')"
if [[ -n "${TB}" ]]; then
    SIZE="${TB}"
else
    SIZE="${GB}"
fi
STORAGE_TYPE='HDD'
if [ "$(lsblk -no ROTA ${DISK} | head -1)" -eq 0 ]; then
    STORAGE_TYPE='SSD'
    RPM=''
fi


echo "${SIZE};${FAMILY};${MODEL};${SERIAL};${RPM};${FF};${SS};${INTERFACE};${STORAGE_TYPE}" | tr -cd '\11\12\15\40-\176'
