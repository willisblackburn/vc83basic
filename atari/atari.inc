; Vectors

CIOV        := $E456    ; Central I/O vector

; IOCB addresses

IOCBSZ      = 16        ; IOCB size

IOCB        := $0340
ICHID       := $0340
ICDNO       := $0341
ICCOM       := $0342
ICSTA       := $0343
ICBAL       := $0344
ICBAH       := $0345
ICPTL       := $0346
ICPTH       := $0347
ICBLL       := $0348
ICBLH       := $0349
ICAX1       := $034A
ICAX2       := $034B
ICAX3       := $034C
ICAX4       := $034D
ICAX5       := $034E
ICSPR       := $034F

; IOCB command codes

OPEN        = $03
GETREC      = $05
GETCHR      = $07
PUTREC      = $09
PUTCHR      = $0B
CLOSE       = $0C
STATIS      = $0D
SPECIL      = $0E
RENAME      = $20
DELETE      = $21
LOCKFL      = $23
UNLOCK      = $24
POINT       = $25
NOTE        = $26
GETFL       = $27
