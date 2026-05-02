; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

initialize_target = initialize_target_apple2_lc

.include "basic.s"
.include "main.s"
.include "apple2/apple2.inc"
.include "apple2/apple2_startup.s"
.include "apple2/apple2_init.s"
.include "apple2/apple2_init_lc.s"
.include "apple2/apple2_io.s"
.include "apple2/apple2_extension_lc.s"
