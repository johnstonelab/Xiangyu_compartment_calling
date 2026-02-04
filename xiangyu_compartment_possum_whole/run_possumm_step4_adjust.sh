#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash run_possumm_step4_adjust.sh \
#     --chrom-sizes mm10.chrom.ordered.sizes \
#     --signs chr.signs \
#     --initial-bedgraph /path/to/<base>.initial.bedgraph \
#     --possum-dir /path/to/all/codes \
#     --outdir /path/to/out_adjusted

CHROM_SIZES=""
SIGNS=""
INITIAL_BG=""
POSSUM_DIR=""
OUTDIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --chrom-sizes)    CHROM_SIZES="$2"; shift 2;;
    --signs)          SIGNS="$2"; shift 2;;
    --initial-bedgraph) INITIAL_BG="$2"; shift 2;;
    --possum-dir)     POSSUM_DIR="$2"; shift 2;;
    --outdir)         OUTDIR="$2"; shift 2;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

if [[ -z "${CHROM_SIZES}" || -z "${SIGNS}" || -z "${INITIAL_BG}" || -z "${POSSUM_DIR}" || -z "${OUTDIR}" ]]; then
  echo "Missing required arguments." >&2
  exit 1
fi

BEDGRAPH2BW="${POSSUM_DIR}/bedGraphToBigWig"
if [[ ! -x "${BEDGRAPH2BW}" ]]; then
  echo "ERROR: bedGraphToBigWig not found or not executable at: ${BEDGRAPH2BW}" >&2
  exit 1
fi

mkdir -p "${OUTDIR}/bedgraph_adjusted" "${OUTDIR}/bigwig_adjusted"

BASE="$(basename "${INITIAL_BG}")"
BASE="${BASE%.initial.bedgraph}"

OUT_BG="${OUTDIR}/bedgraph_adjusted/${BASE}.adjusted.bedgraph"
OUT_BW="${OUTDIR}/bigwig_adjusted/${BASE}.adjusted.sorted.bw"


#R part, CHROM_sizes may not be important here.
R_ADJUST_SCRIPT="${POSSUM_DIR}/adjust_possum_signs.R"

Rscript "${R_ADJUST_SCRIPT}" \
  "${SIGNS}" \
  "${INITIAL_BG}" \
  "${OUT_BG}"
#R part


# sort + bigwig
SORTED_BG="${OUT_BG%.bedgraph}.sorted.bedgraph"
LC_COLLATE=C sort -k1,1 -k2,2n -k3,3n "${OUT_BG}" > "${SORTED_BG}"

"${BEDGRAPH2BW}" "${SORTED_BG}" "${CHROM_SIZES}" "${OUT_BW}"

echo "[Done] Step 4 complete."
echo "Adjusted bedGraph: ${OUT_BG}"
echo "Adjusted bigWig  : ${OUT_BW}"
