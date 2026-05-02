; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.segment "STARTUP"

reset_handler:
        lda     LCRAMWP                 ; Re-enable LC RAM for reading after hardware RESET
        raise   PS_READY

.code
