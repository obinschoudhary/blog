#!/bin/bash

set -o nounset
set -o errexit

VERBOSE_MODE=0

function error_handler()
{
  local STATUS=${1:-1}
  [ ${VERBOSE_MODE} == 0 ] && exit ${STATUS}
  echo "Exits abnormally at line "`caller 0`
  exit ${STATUS}
}
trap "error_handler" ERR

PROGNAME=`basename ${BASH_SOURCE}`
DRY_RUN_MODE=0

function print_usage_and_exit()
{
  set +x
  local STATUS=$1
  echo "Usage: ${PROGNAME} [-v] [-v] [--dry-run] [-h] [--help]"
  echo ""
  echo " Options -"
  echo "  -v                 enables verbose mode 1"
  echo "  -v -v              enables verbose mode 2"
  echo "      --dry-run      show what would have been dumped"
  echo "  -h, --help         shows this help message"
  exit ${STATUS:-0}
}

function debug()
{
  if [ "$VERBOSE_MODE" != 0 ]; then
    echo $@
  fi
}

GETOPT=`getopt -o vh --long dry-run,help -n "${PROGNAME}" -- "$@"`
if [ $? != 0 ] ; then print_usage_and_exit 1; fi

eval set -- "${GETOPT}"

while true
do case "$1" in
     -v)            let VERBOSE_MODE+=1; shift;;
     --dry-run)     DRY_RUN_MODE=1; shift;;
     -h|--help)     print_usage_and_exit 0;;
     --)            shift; break;;
     *) echo "Internal error!"; exit 1;;
   esac
done

if (( VERBOSE_MODE > 1 )); then
  set -x
fi


# template area is ended.
# -----------------------------------------------------------------------------
if [ ${#} != 0 ]; then print_usage_and_exit 1; fi

# current dir of this script
CDIR=$(readlink -f $(dirname $(readlink -f ${BASH_SOURCE[0]})))

[[ -f ${CDIR}/env.sh ]] && . ${CDIR}/env.sh || exit

# -----------------------------------------------------------------------------
# functions



# end functions
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# main

make_calmness
child_verbose=""
if (( VERBOSE_MODE > 1 )); then
    revert_calmness
    child_verbose="-v -v"
fi

${IRSTLM}/dict -InputFile=${DOC} -OutputFile=${DICT} -Freq=yes -sort=no
${IRSTLM}/split-dict.pl --input ${DICT} --output ${DICT}. --parts ${SPLIT}
for subdict in `ls ${DICT}.*`
do
    filename=$(basename "$subdict")
    extension="${filename##*.}"
    ${IRSTLM}/ngt -InputFile=${DOC} -FilterDict=${filename} -NgramSize=${NGRAM_SIZE} -OutputFile=${NGRAM}.${extension} -OutputGoogleFormat=yes
done

for subngram in `ls ${NGRAM}.*`
do
    filename=$(basename "$subngram")
    extension="${filename##*.}"
    ${IRSTLM}/build-sublm.pl --size ${NGRAM_SIZE} --ngrams ${subngram} --sublm ${LM}.${extension}
done

${IRSTLM}/merge-sublm.pl --size ${NGRAM_SIZE} --sublm ${LM} -lm ${iARPA}.gz

function optional {
    ${IRSTLM}/quantize-lm ${iARPA} ${qARPA}
}

gunzip ${iARPA}.gz
${IRSTLM}/compile-lm --text=yes ${iARPA} ${ARPA}

${KENLM}/build_binary -s -i -w mmap ${ARPA} ${ARPA}.mmap

close_fd

# end main
# -----------------------------------------------------------------------------
