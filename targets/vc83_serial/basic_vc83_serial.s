; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

enable_trig_functions = 1
enable_io_channels    = 1

.include "vc83_serial.inc"
.include "basic.s"
.include "main.s"
.include "vc83_serial_startup.s"
.include "vc83_serial_init.s"
.include "vc83_serial_io.s"
.include "vc83_serial_extension.s"
