# ANTs to FSL Converter

A lightweight Bash tool to convert ANTs-composite transforms (`.h5`) into FSL-compatible warp fields (`.nii.gz`).

This tool automates the disassembly of ANTs transforms, converts deformation fields using Connectome Workbench, converts affine matrices using C3D, and combines them into a single FSL warp field.

## Features
- **Automated Workflow**: One-step conversion from ANTs H5 to FSL Warp.
- **Space Handling**: Supports both Native-to-MNI and MNI-to-Native conversions.
- **Robustness**: Includes strict error handling and dependency checking.

## Requirements
Ensure the following tools are installed and added to your system `$PATH`:
* **ANTs** (`CompositeTransformUtil`)
* **FSL** (`convertwarp`)
* **Connectome Workbench** (`wb_command`)
* **Convert3D** (`c3d_affine_tool`)
* **Python 3** (with `fsl` library)

To install the Python dependency:
```bash
pip install fslpy
```

## Installation

1. Clone this repository:
```bash
git clone https://github.com/weiwang-23/ants2fsl-converter.git
cd ants2fsl-converter
```

2. Make the script executable:
```bash
chmod +x ants2fsl_converter.sh
```

## Usage
```bash
./ants2fsl_converter.sh <ANTS_XFM> <T1W_IMAGE> <MNI_IMAGE> <SRC_FLAG>
```

### Arguments

- `ANTS_XFM`: Path to the input ANTs `.h5` transform file.
- `T1W_IMAGE`: Path to the T1w image (Native space reference).
- `MNI_IMAGE`: Path to the MNI standard template (Standard space reference).
- `SRC_FLAG`: The source space of the transform:
    - `native`: Use this if the transform moves data **from Native to MNI**.
    - `mni`: Use this if the transform moves data **from MNI to Native**.

### Example

**Convert a Native -> MNI transform:**
```bash
./ants2fsl_converter.sh \
  /data/sub-01/transforms/sub-01_from-native_to-MNI_xfm.h5 \
  /data/sub-01/anat/sub-01_T1w.nii.gz \
  /templates/tpl-MNI152NLin2009cAsym_res-01_T1w.nii.gz \
  native
```

## Output

The script will generate the FSL-compatible warp file in the same directory as the input `.h5` file:

- `sub-01_from-native_to-MNI_xfm_fsl.nii.gz`

## License

This project is licensed under the MIT License - see the **LICENSE** file for details.

## Author

Developed by **Wei Wang** (Beijing Normal University).
Contact: wei.wang@mail.bnu.edu.cn