; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.segment "STARTUP"

reset_handler:
        raise   PS_READY

.code
