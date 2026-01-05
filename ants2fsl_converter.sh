#!/bin/bash

# ==============================================================================
# Script Name: ants2fsl_converter.sh
# Version: 1.0.0
# Description: Convert ANTs composite transforms (.h5) to FSL format (.nii.gz).
#              The script operates in the directory of the input ANTs transform.
#              Intermediate files are stored in a temporary subfolder 'tmp_ants2fsl'.
#
# Author: Wei Wang
# Email:  wei.wang@mail.bnu.edu.cn
# Institution: Beijing Normal University
# GitHub: https://github.com/weiwang-23/ants2fsl-converter
# License: MIT License (See LICENSE file for details)
#
# Usage: ./ants2fsl_converter.sh <ANTS_XFM> <T1W_IMAGE> <MNI_IMAGE> <SRC_FLAG>
# ==============================================================================

# Set strict mode
set -euo pipefail

# ==============================================================================
# 0. Self-Location & Helper Script Setup
# ==============================================================================

# Automatically determine the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define the path to the helper Python script (expects it in the same directory)
HELPER_SCRIPT="${SCRIPT_DIR}/utils/add_xfm_intent.py"

# Check if the helper script exists
if [ ! -f "${HELPER_SCRIPT}" ]; then
    echo "Error: Helper script 'add_xfm_intent.py' not found in ${SCRIPT_DIR}."
    echo "Please ensure the python script is located alongside this bash script."
    exit 1
fi

# ==============================================================================
# 1. Helper Functions
# ==============================================================================

usage() {
    cat <<EOF
Usage: $(basename "$0") <ANTS_XFM> <T1W_IMAGE> <MNI_IMAGE> <SRC_FLAG>

Arguments:
  1. ANTS_XFM   : Path to the input ANTs .h5 transform file
  2. T1W_IMAGE  : Path to the T1w image (native space reference)
  3. MNI_IMAGE  : Path to MNI standard template (standard space reference)
  4. SRC_FLAG   : Source space name ('native' or 'mni')
                  * If 'native': Converts Native -> MNI
                  * If 'mni'   : Converts MNI -> Native

Example:
  bash $(basename "$0") /path/to/transform.h5 /path/to/t1w.nii.gz /path/to/MNI.nii.gz native
EOF
    exit 1
}

# Function to get absolute path
get_abs_path() {
    local file="$1"
    if [ -d "$(dirname "$file")" ]; then
        echo "$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
    else
        echo "$file"
    fi
}

# Check argument count (Updated to 4 arguments)
if [ "$#" -ne 4 ]; then
    echo "Error: Incorrect number of arguments provided. Expected 4, got $#."
    usage
fi

# ==============================================================================
# 2. Dependency Check
# ==============================================================================

# Check if necessary tools are available in PATH
for tool in CompositeTransformUtil wb_command c3d_affine_tool convertwarp python; do
    if ! command -v "$tool" &> /dev/null; then
        echo "Error: Required tool '$tool' not found in PATH."
        exit 1
    fi
done

# ==============================================================================
# 3. Input Handling & Path Resolution
# ==============================================================================

# Assign inputs and convert to absolute paths immediately
ANTS_XFM=$(get_abs_path "$1")
T1W_IMAGE=$(get_abs_path "$2")
MNI_IMAGE=$(get_abs_path "$3")
# CODE_DIR was removed
SRC_FLAG=$4

echo ">>> Starting conversion..."
echo "    Transform: ${ANTS_XFM}"

# Check existence of inputs
for file in "$ANTS_XFM" "$T1W_IMAGE" "$MNI_IMAGE"; do
    if [ ! -f "$file" ]; then
        echo "Error: Input file not found: $file"
        exit 1
    fi
done

# ==============================================================================
# 4. Setup Directories & Space Logic
# ==============================================================================

# Get the directory of the ANTs XFM file and switch to it
WORK_DIR=$(dirname "${ANTS_XFM}")
cd "${WORK_DIR}"
echo ">>> Working Directory switched to: ${WORK_DIR}"

# Create a temporary directory for intermediate files
TMP_DIR="${WORK_DIR}/tmp_ants2fsl"
mkdir -p "${TMP_DIR}"

# Determine reference/source images and REF_FLAG based on flags
if [[ "${SRC_FLAG}" == *mni* ]]; then
    # MNI -> Native
    SRC_IMAGE=${MNI_IMAGE}
    REF_IMAGE=${T1W_IMAGE}
    REF_FLAG="native"
    MAT_FLAG="postmat"
elif [[ "${SRC_FLAG}" == *native* ]]; then
    # Native -> MNI
    SRC_IMAGE=${T1W_IMAGE}
    REF_IMAGE=${MNI_IMAGE}
    REF_FLAG="mni"
    MAT_FLAG="premat"
else
    echo "Error: Unknown SRC_FLAG: ${SRC_FLAG}. Expected 'native' or 'mni'."
    exit 1
fi

echo "    Direction: ${SRC_FLAG} -> ${REF_FLAG}"

# ==============================================================================
# 5. Main Processing Steps
# ==============================================================================

# ===== Step 1: Disassemble .h5 composite transform =====
echo "--- Step 1: Disassemble ANTs transform ---"
# CompositeTransformUtil outputs files in the current dir based on input name.
CompositeTransformUtil --disassemble "${ANTS_XFM}" "from-${SRC_FLAG}_to-${REF_FLAG}"

# Move the disassembled files to TMP_DIR to keep WORK_DIR clean
# Find the newly created files (using ls -t)
RAW_AFFINE=$(ls -t *AffineTransform*.mat | head -n 1)
RAW_WARP=$(ls -t *DisplacementFieldTransform*.nii.gz | head -n 1)

if [[ -z "$RAW_AFFINE" || -z "$RAW_WARP" ]]; then
    echo "Error: Failed to identify disassembled transform components."
    exit 1
fi

# Move them to TMP_DIR and update variables
mv "$RAW_AFFINE" "${TMP_DIR}/"
mv "$RAW_WARP" "${TMP_DIR}/"
ANTS_AFFINE="${TMP_DIR}/$(basename "$RAW_AFFINE")"
ANTS_WARP="${TMP_DIR}/$(basename "$RAW_WARP")"

# ===== Step 2: Convert ANTs warp to FSL warp =====
echo "--- Step 2: Convert ANTs warp to FSL warp ---"
FSL_WARP="${TMP_DIR}/fsl_warp.nii.gz"  # Save to TMP_DIR

wb_command -convert-warpfield \
    -from-itk "${ANTS_WARP}" \
    -to-fnirt "${FSL_WARP}" "${SRC_IMAGE}"

# Call helper script using the auto-detected path
python "${HELPER_SCRIPT}" -i "${FSL_WARP}" -o "${FSL_WARP}"

# ===== Step 3: Convert ANTs affine to FSL affine =====
echo "--- Step 3: Convert ANTs affine to FSL affine ---"
FSL_AFFINE="${TMP_DIR}/fsl_affine.mat" # Save to TMP_DIR

c3d_affine_tool \
    -src "${SRC_IMAGE}" \
    -ref "${REF_IMAGE}" \
    -itk "${ANTS_AFFINE}" \
    -ras2fsl \
    -o "${FSL_AFFINE}"

# ===== Step 4: Combine FSL affine and warp =====
echo "--- Step 4: Create final FSL transform ---"

# Construct Output Filename based on input ANTs filename
BASE_NAME=$(basename "${ANTS_XFM}" .h5)
FSL_XFM="${WORK_DIR}/${BASE_NAME}_fsl.nii.gz" # Save to WORK_DIR

convertwarp \
    --ref="${REF_IMAGE}" \
    --${MAT_FLAG}="${FSL_AFFINE}" \
    --warp1="${FSL_WARP}" \
    --out="${FSL_XFM}"

# Call helper script using the auto-detected path
python "${HELPER_SCRIPT}" -i "${FSL_XFM}" -o "${FSL_XFM}"

echo "    Output FSL transform saved to: ${FSL_XFM}"

# ==============================================================================
# 6. Cleanup
# ==============================================================================
echo "--- Cleanup ---"
# Remove the entire temporary directory
if [ -d "${TMP_DIR}" ]; then
    rm -rf "${TMP_DIR}"
fi

echo ">>> Successfully completed processing."
