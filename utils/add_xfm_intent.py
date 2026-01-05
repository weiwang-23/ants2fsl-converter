#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script Name: add_xfm_intent.py
Description: Helper script to fix NIfTI intent codes for FSL compatibility.

Author: Wei Wang
Email:  wei.wang@mail.bnu.edu.cn
Institution: Beijing Normal University
GitHub: https://github.com/weiwang-23/ants2fsl-converter
License: MIT License
"""


import argparse
import fsl.data.image as fslimage


def get_arguments():

    parser = argparse.ArgumentParser()

    parser.add_argument('-i', type=str, required=True, help='Input nifti file that the header is vacent.')
    parser.add_argument('-o', type=str, default='out.nii.gz', help='Output nifti file with the header added.')

    return parser.parse_args()


if __name__ == '__main__':

    args = get_arguments()

    img = fslimage.Image(args.i)

    # Revise intent of the image to 2006 which is the displacement field constant is FSL Format
    img.intent = 2006

    # Save the image
    img.save(args.o)