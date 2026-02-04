#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Step 2: compartment per chr + initial bedGraph/bigWig
# -----------------------------
# Usage:
#   bash run_possumm_step2.sh \
#     --chrom-sizes mm10.chrom.ordered.sizes \
#     --chr-res chr.resolution.tsv \
#     --hic merge_Ctl_MicroC.hic \
#     --outdir /path/to/out \
#     --possum-dir /path/to/all/codes
#     --norm KR or other methods
#
# Output:
#   outdir/possum_outputs/<base>_<res>_<chr>_output
#   outdir/bedgraph_initial/<base>.initial.bedgraph
#   outdir/bigwig_initial/<base>.initial.bw
# -----------------------------

CHROM_SIZES=""
CHR_RES=""
HIC=""
OUTDIR=""
POSSUM_DIR=""
NORM=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --chrom-sizes) CHROM_SIZES="$2"; shift 2;;
    --chr-res)     CHR_RES="$2"; shift 2;;
    --hic)         HIC="$2"; shift 2;;
    --outdir)      OUTDIR="$2"; shift 2;;
    --possum-dir)  POSSUM_DIR="$2"; shift 2;;
    --norm)  NORM="$2"; shift 2;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

if [[ -z "${CHROM_SIZES}" || -z "${CHR_RES}" || -z "${HIC}" || -z "${OUTDIR}" || -z "${POSSUM_DIR}" || -z "${NORM}" ]]; then
  echo "Missing required arguments. See header usage." >&2
  exit 1
fi

EIG_SCRIPT="${POSSUM_DIR}/EigenVector/R/eigFromHicRscript.R"
BEDGRAPH2BW="${POSSUM_DIR}/bedGraphToBigWig"   # place this in the same directory
if [[ ! -f "${EIG_SCRIPT}" ]]; then
  echo "ERROR: Cannot find eigFromHicRscript.R at: ${EIG_SCRIPT}" >&2
  exit 1
fi
if [[ ! -x "${BEDGRAPH2BW}" ]]; then
  echo "ERROR: bedGraphToBigWig not found or not executable at: ${BEDGRAPH2BW}" >&2
  echo "Tip: chmod +x ${BEDGRAPH2BW}" >&2
  exit 1
fi

mkdir -p "${OUTDIR}/possum_outputs" "${OUTDIR}/bedgraph_initial" "${OUTDIR}/bigwig_initial"

BASE="$(basename "${HIC}" .hic)"


echo "[Step2a] Running POSSUMM on: ${HIC}"
echo "        base name: ${BASE}"
echo "        chrom sizes: ${CHROM_SIZES}"
echo "        chr-resolution: ${CHR_RES}"
echo "        outdir: ${OUTDIR}"
echo "        norm: ${NORM}"

# Build lookup table: chr -> resolution
# Format: chr<TAB>res
declare -A RES_MAP
while read -r chr res; do
  [[ -z "${chr}" ]] && continue
  RES_MAP["${chr}"]="${res}"
  echo "[CHR_RES] chr=${chr}, res=${res}"
done < "${CHR_RES}"

# Loop chromosomes in chrom sizes order
while read -r CHR_NAME CHR_LENGTH; do
  [[ -z "${CHR_NAME}" ]] && continue

  # OPTIONAL: skip chrM/chrY (matches your old behavior)
  if [[ "${CHR_NAME}" == "chrM" || "${CHR_NAME}" == "chrY" ]]; then
    echo "[Step2a] Skipping ${CHR_NAME} (by design)."
    continue
  fi

  RES="${RES_MAP[${CHR_NAME}]:-}"
  if [[ -z "${RES}" ]]; then
    echo "ERROR: No resolution found for ${CHR_NAME} in ${CHR_RES}" >&2
    exit 1
  fi

  OUTFILE="${OUTDIR}/possum_outputs/${BASE}_${RES}_${CHR_NAME}_output"

  echo "------------------------------------------------------------"
  echo "[Step2a] Chr: ${CHR_NAME} | Length: ${CHR_LENGTH} | Res: ${RES}"
  echo "        Output: ${OUTFILE}"
  echo "        Normalization: ${NORM}"
  echo "[Step2a] Running: Rscript eigFromHicRscript.R -n ${NORM} -s ${CHR_LENGTH} ${HIC} ${CHR_NAME} ${OUTFILE} ${RES}"

  # Run POSSUMM (no sbatch; direct call). cd happens only inside the parentheses. When the command finishes, the script returns to the original directory
  ( cd "${POSSUM_DIR}/EigenVector/R" && \
    Rscript "${EIG_SCRIPT}" -n "${NORM}" -s "${CHR_LENGTH}" "${HIC}" "${CHR_NAME}" "${OUTFILE}" "${RES}" )

done < "${CHROM_SIZES}"


echo "------------------------------------------------------------"
echo "[Step2b] Building initial bedGraph + bigWig via R"


R_BEDGRAPH_SCRIPT="${POSSUM_DIR}/make_possum_bedgraph_bigwig.R"
if [[ ! -f "${R_BEDGRAPH_SCRIPT}" ]]; then
  echo "ERROR: Cannot find R script at: ${R_BEDGRAPH_SCRIPT}" >&2
  exit 1
fi

OUT_BEDGRAPH="${OUTDIR}/bedgraph_initial/${BASE}.initial.bedgraph"
OUT_BIGWIG="${OUTDIR}/bigwig_initial/${BASE}.initial.sorted.bw"

Rscript "${R_BEDGRAPH_SCRIPT}" \
  "${CHROM_SIZES}" \
  "${CHR_RES}" \
  "${OUTDIR}/possum_outputs" \
  "${BASE}" \
  "${BEDGRAPH2BW}" \
  "${OUT_BEDGRAPH}" \
  "${OUT_BIGWIG}"

echo "[Done] Step 2 complete."
