#version 450

/*

Patchy68k Fast Multipass - Simulation of analog video signal artifacts and color correction
Copyright (C) 2025 Patchy68k/PlainOldPants

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>. 

*/

/*

https://pub.smpte.org/doc/st170/20041130-pub/st0170-2004_stable2010.pdf
SMPTE 170M-2004 - Composite Analog Video Signal - NTSC for Studio Applications

This pass performs the following operations (not in order):

* Convert RGB into YIQ (default) or Y B-Y R-Y
* Correct the transfer characteristic (gamma):
    * Electro-optical transfer: power 2.2 (default), sRGB piecewise
    * Opto-electronic transfer: power 2.2 (default), sRGB piecewise, 170M/240M/BT.709
* Correct RGB primaries and reference white:
    * Input primaries and reference white are assumed to be sRGB
    * Output primaries: sRGB, SMPTE C, NTSC 1953 (default)
    * Output white: D65 (default), C, 9300K+8MPCD

Note that many of the above options are not allowed by the video standard.
No effort is made to prevent clipping when converting between different primaries. Please be careful.

In a future version, interlacing will be supported. Currently, only "double-struck" 240p is supported.

When putting this in a shader preset, use the following settings:

Input must use nearest-neighbor interpolation.
Input sizes should be the same as the output sizes.
Framebuffer should use floating point, not integers.

*/

#include "p68k-fast-mp-pre-color-interlace-170m.inc"
