; ------------------------------------------------------------------------------
; Functions for calculating the natural logarithm and the logarithm base 2
; of AVX2 ymm registers
; ------------------------------------------------------------------------------

%define _CMP_LT_OQ 17
%define _CMP_EQ_OQ 0


    global mm256_log_pd
    global mm256_log_ps
    global mm256_log2_pd
    global mm256_log2_ps
    global mm256_log10_pd
    global mm256_log10_ps

    section .text

; natural logarithm of 4 packed double precision values
; returns NaN for values < 0
; returns -inf for 0 and denormals
; returns +inf for +inf

; log(x) = log(m*2^e) = log(m) + e*log(2) with m \in [1/sqrt(2), sqrt(2))
; log(m) = 2*artanh((m-1)/(m+1)) = 2r + 2r^3/3 + 2r^5/5 + ... with r := (m-1)/(m+1)

mm256_log_pd:
    vmovapd ymm15, [inf_pd] ; ymm15 := Inf
    vmovapd ymm14, [one_pd] ; ymm14 := 1.0

    ; special return values masks
    vxorpd ymm1, ymm1                        ; ymm1 := 0
    vcmppd ymm13, ymm0, [min_pd], _CMP_LT_OQ ; mask denormals and lower to return -inf
    vcmppd ymm12, ymm0, ymm1,     _CMP_LT_OQ ; mask x<0 to return NaN
    vcmppd ymm11, ymm0, ymm15,    _CMP_EQ_OQ ; mask x=+inf to return +inf

    ; extract mantissa
    vandnpd ymm1,  ymm15, ymm0    ; not(+inf) is just the right mask to extract the (signed) mantissa
    vorpd   ymm2,  ymm1, [hlf_pd] ; mantissa / 2
    vorpd   ymm1,  ymm14          ; normalize mantissa
    vcmppd  ymm10, ymm1, [sqrt_pd], _CMP_LT_OQ ; mask x<sqrt(2)

    ; extract exponent
    vmovapd ymm3, [idx_si]
    vpsrld  ymm0, 20
    vpsubd  ymm0, [bias_pd]
    vpermd  ymm0, ymm3, ymm0
    vcvtdq2pd ymm0, xmm0
    vaddpd  ymm3, ymm0, ymm14

    ; restric mantissa to [1/sqrt(2), sqrt(2)) and adjust exponent
    vblendvpd ymm3, ymm0, ymm10
    vblendvpd ymm2, ymm1, ymm10

    vmulpd ymm3, [log2_pd] ; log(2^e) = e*log(2)

    ; r = (m-1)/(m+1)
    vsubpd ymm1, ymm2, ymm14
    vaddpd ymm2, ymm14
    vdivpd ymm1, ymm2
    vmovapd ymm0, ymm1 ; ymm0 := r
    vmulpd ymm1, ymm1  ; ymm1 := r^2

    ; evaluate polynomial
    vmovapd ymm2, [e7_pd]

    vfmadd213pd ymm2, ymm1, [e6_pd]
    vfmadd213pd ymm2, ymm1, [e5_pd]
    vfmadd213pd ymm2, ymm1, [e4_pd]
    vfmadd213pd ymm2, ymm1, [e3_pd]
    vfmadd213pd ymm2, ymm1, [e2_pd]
    vfmadd213pd ymm2, ymm1, [e1_pd]
    vfmadd213pd ymm2, ymm1, [e0_pd]

    vfmadd213pd ymm0, ymm2, ymm3

    ; Blend special return values into result
    vxorpd ymm2, ymm2
    vsubpd ymm2, ymm15
    vblendvpd ymm0, ymm15, ymm11
    vblendvpd ymm0, ymm2, ymm13
    vorpd ymm0, ymm12

    ret


; natural logarithm of 8 packed single precision values
; returns NaN for values < 0
; returns -inf for 0 and denormals
; returns +inf for +inf

mm256_log_ps:
    vmovaps ymm15, [inf_ps] ; ymm15 := Inf
    vmovaps ymm14, [one_ps] ; ymm14 := 1.0

    ; special return values masks
    vxorps ymm1, ymm1                        ; ymm1 := 0
    vcmpps ymm13, ymm0, [min_ps], _CMP_LT_OQ ; mask denormals and lower to return -inf
    vcmpps ymm12, ymm0, ymm1,     _CMP_LT_OQ ; mask x<0 to return NaN
    vcmpps ymm11, ymm0, ymm15,    _CMP_EQ_OQ ; mask x=+inf to return +inf

    ; extract mantissa
    vandnps ymm1,  ymm15, ymm0    ; not(+inf) is just the right mask to extract the (signed) mantissa
    vorps   ymm2,  ymm1, [hlf_ps] ; mantissa / 2
    vorps   ymm1,  ymm14          ; normalize mantissa
    vcmpps  ymm10, ymm1, [sqrt_ps], _CMP_LT_OQ ; mask x<sqrt(2)

    ; extract exponent
    vpsrld  ymm0, 23
    vpsubd  ymm0, [bias_ps]
    vcvtdq2ps ymm0, ymm0
    vaddps  ymm3, ymm0, ymm14

    ; restric mantissa to [1/sqrt(2), sqrt(2)) and adjust exponent
    vblendvps ymm3, ymm0, ymm10
    vblendvps ymm2, ymm1, ymm10

    vmulps ymm3, [log2_ps] ; log(2^e) = e*log(2)

    ; r = (m-1)/(m+1)
    vsubps ymm1, ymm2, ymm14
    vaddps ymm2, ymm14
    vdivps ymm1, ymm2
    vmovaps ymm0, ymm1 ; ymm0 := r
    vmulps ymm1, ymm1  ; ymm1 := r^2

    ; evaluate polynomial
    vmovaps ymm2, [e3_ps]

    vfmadd213ps ymm2, ymm1, [e2_ps]
    vfmadd213ps ymm2, ymm1, [e1_ps]
    vfmadd213ps ymm2, ymm1, [e0_ps]

    vfmadd213ps ymm0, ymm2, ymm3

    ; Blend special return values into result
    vxorps ymm2, ymm2
    vsubps ymm2, ymm15
    vblendvps ymm0, ymm15, ymm11
    vblendvps ymm0, ymm2, ymm13
    vorps ymm0, ymm12

    ret



; base 2 logarithm of 4 packed double precision values
; returns NaN for values < 0
; returns -inf for 0 and denormals
; returns +inf for +inf

; log2(x) = log2(m*2^e) = log(m)/log(2) + e with m \in [1/sqrt(2), sqrt(2))
; log2(m) = 2/log2(e)*artanh((m-1)/(m+1)) = 2/log2(e)*(r + r^3/3 + r^5/5 + ...) with r := (m-1)/(m+1)

mm256_log2_pd:
    vmovapd ymm15, [inf_pd] ; ymm15 := Inf
    vmovapd ymm14, [one_pd] ; ymm14 := 1.0

    ; special return values masks
    vxorpd ymm1, ymm1                        ; ymm1 := 0
    vcmppd ymm13, ymm0, [min_pd], _CMP_LT_OQ ; mask denormals and lower to return -inf
    vcmppd ymm12, ymm0, ymm1,     _CMP_LT_OQ ; mask x<0 to return NaN
    vcmppd ymm11, ymm0, ymm15,    _CMP_EQ_OQ ; mask x=+inf to return +inf

    ; extract mantissa
    vandnpd ymm1,  ymm15, ymm0    ; not(+inf) is just the right mask to extract the (signed) mantissa
    vorpd   ymm2,  ymm1, [hlf_pd] ; mantissa / 2
    vorpd   ymm1,  ymm14          ; normalize mantissa
    vcmppd  ymm10, ymm1, [sqrt_pd], _CMP_LT_OQ ; mask x<sqrt(2)

    ; extract exponent
    vmovapd ymm3, [idx_si]
    vpsrld  ymm0, 20
    vpsubd  ymm0, [bias_pd]
    vpermd  ymm0, ymm3, ymm0
    vcvtdq2pd ymm0, xmm0
    vaddpd  ymm3, ymm0, ymm14

    ; restric mantissa to [1/sqrt(2), sqrt(2)) and adjust exponent
    vblendvpd ymm3, ymm0, ymm10
    vblendvpd ymm2, ymm1, ymm10

    ; r = (m-1)/(m+1)
    vsubpd ymm1, ymm2, ymm14
    vaddpd ymm2, ymm14
    vdivpd ymm1, ymm2
    vmovapd ymm0, ymm1 ; ymm0 := r
    vmulpd ymm1, ymm1  ; ymm1 := r^2

    ; evaluate polynomial
    vmovapd ymm2, [p7_pd]

    vfmadd213pd ymm2, ymm1, [p6_pd]
    vfmadd213pd ymm2, ymm1, [p5_pd]
    vfmadd213pd ymm2, ymm1, [p4_pd]
    vfmadd213pd ymm2, ymm1, [p3_pd]
    vfmadd213pd ymm2, ymm1, [p2_pd]
    vfmadd213pd ymm2, ymm1, [p1_pd]
    vfmadd213pd ymm2, ymm1, [p0_pd]

    vfmadd213pd ymm0, ymm2, ymm3

    ; Blend special return values into result
    vxorpd ymm2, ymm2
    vsubpd ymm2, ymm15
    vblendvpd ymm0, ymm15, ymm11
    vblendvpd ymm0, ymm2, ymm13
    vorpd ymm0, ymm12

    ret


; base 2 logarithm of 8 packed single precision values
; returns NaN for values < 0
; returns -inf for 0 and denormals
; returns +inf for +inf

mm256_log2_ps:
    vmovaps ymm15, [inf_ps] ; ymm15 := Inf
    vmovaps ymm14, [one_ps] ; ymm14 := 1.0

    ; special return values masks
    vxorps ymm1, ymm1                        ; ymm1 := 0
    vcmpps ymm13, ymm0, [min_ps], _CMP_LT_OQ ; mask denormals and lower to return -inf
    vcmpps ymm12, ymm0, ymm1,     _CMP_LT_OQ ; mask x<0 to return NaN
    vcmpps ymm11, ymm0, ymm15,    _CMP_EQ_OQ ; mask x=+inf to return +inf

    ; extract mantissa
    vandnps ymm1,  ymm15, ymm0    ; not(+inf) is just the right mask to extract the (signed) mantissa
    vorps   ymm2,  ymm1, [hlf_ps] ; mantissa / 2
    vorps   ymm1,  ymm14          ; normalize mantissa
    vcmpps  ymm10, ymm1, [sqrt_ps], _CMP_LT_OQ ; mask x<sqrt(2)

    ; extract exponent
    vpsrld  ymm0, 23
    vpsubd  ymm0, [bias_ps]
    vcvtdq2ps ymm0, ymm0
    vaddps  ymm3, ymm0, ymm14

    ; restric mantissa to [1/sqrt(2), sqrt(2)) and adjust exponent
    vblendvps ymm3, ymm0, ymm10
    vblendvps ymm2, ymm1, ymm10

    ; r = (m-1)/(m+1)
    vsubps ymm1, ymm2, ymm14
    vaddps ymm2, ymm14
    vdivps ymm1, ymm2
    vmovaps ymm0, ymm1 ; ymm0 := r
    vmulps ymm1, ymm1  ; ymm1 := r^2

    ; evaluate polynomial
    vxorps ymm4, ymm4
    vmovaps ymm2, [p3_ps]

    vfmadd213ps ymm2, ymm1, [p2_ps]
    vfmadd213ps ymm2, ymm1, [p1_ps]
    vfmadd213ps ymm2, ymm1, [p0_ps]

    vfmadd213ps ymm0, ymm2, ymm3

    ; Blend special return values into result
    vxorps ymm2, ymm2
    vsubps ymm2, ymm15
    vblendvps ymm0, ymm15, ymm11
    vblendvps ymm0, ymm2, ymm13
    vorps ymm0, ymm12

    ret




mm256_log10_pd:
    vmovapd ymm15, [inf_pd] ; ymm15 := Inf
    vmovapd ymm14, [one_pd] ; ymm14 := 1.0

    ; special return values masks
    vxorpd ymm1, ymm1                        ; ymm1 := 0
    vcmppd ymm13, ymm0, [min_pd], _CMP_LT_OQ ; mask denormals and lower to return -inf
    vcmppd ymm12, ymm0, ymm1,     _CMP_LT_OQ ; mask x<0 to return NaN
    vcmppd ymm11, ymm0, ymm15,    _CMP_EQ_OQ ; mask x=+inf to return +inf

    ; extract mantissa
    vandnpd ymm1,  ymm15, ymm0    ; not(+inf) is just the right mask to extract the (signed) mantissa
    vorpd   ymm2,  ymm1, [hlf_pd] ; mantissa / 2
    vorpd   ymm1,  ymm14          ; normalize mantissa
    vcmppd  ymm10, ymm1, [sqrt_pd], _CMP_LT_OQ ; mask x<sqrt(2)

    ; extract exponent
    vmovapd ymm3, [idx_si]
    vpsrld  ymm0, 20
    vpsubd  ymm0, [bias_pd]
    vpermd  ymm0, ymm3, ymm0
    vcvtdq2pd ymm0, xmm0
    vaddpd  ymm3, ymm0, ymm14

    ; restric mantissa to [1/sqrt(2), sqrt(2)) and adjust exponent
    vblendvpd ymm3, ymm0, ymm10
    vblendvpd ymm2, ymm1, ymm10

    vmulpd ymm3, [log10_pd] ; log10(2^e) = e*log10(2)

    ; r = (m-1)/(m+1)
    vsubpd ymm1, ymm2, ymm14
    vaddpd ymm2, ymm14
    vdivpd ymm1, ymm2
    vmovapd ymm0, ymm1 ; ymm0 := r
    vmulpd ymm1, ymm1  ; ymm1 := r^2

    ; evaluate polynomial
    vmovapd ymm2, [d7_pd]

    vfmadd213pd ymm2, ymm1, [d6_pd]
    vfmadd213pd ymm2, ymm1, [d5_pd]
    vfmadd213pd ymm2, ymm1, [d4_pd]
    vfmadd213pd ymm2, ymm1, [d3_pd]
    vfmadd213pd ymm2, ymm1, [d2_pd]
    vfmadd213pd ymm2, ymm1, [d1_pd]
    vfmadd213pd ymm2, ymm1, [d0_pd]

    vfmadd213pd ymm0, ymm2, ymm3

    ; Blend special return values into result
    vxorpd ymm2, ymm2
    vsubpd ymm2, ymm15
    vblendvpd ymm0, ymm15, ymm11
    vblendvpd ymm0, ymm2, ymm13
    vorpd ymm0, ymm12

    ret


; base 10 logarithm of 8 packed single precision values
; returns NaN for values < 0
; returns -inf for 0 and denormals
; returns +inf for +inf

mm256_log10_ps:
    vmovaps ymm15, [inf_ps] ; ymm15 := Inf
    vmovaps ymm14, [one_ps] ; ymm14 := 1.0

    ; special return values masks
    vxorps ymm1, ymm1                        ; ymm1 := 0
    vcmpps ymm13, ymm0, [min_ps], _CMP_LT_OQ ; mask denormals and lower to return -inf
    vcmpps ymm12, ymm0, ymm1,     _CMP_LT_OQ ; mask x<0 to return NaN
    vcmpps ymm11, ymm0, ymm15,    _CMP_EQ_OQ ; mask x=+inf to return +inf

    ; extract mantissa
    vandnps ymm1,  ymm15, ymm0    ; not(+inf) is just the right mask to extract the (signed) mantissa
    vorps   ymm2,  ymm1, [hlf_ps] ; mantissa / 2
    vorps   ymm1,  ymm14          ; normalize mantissa
    vcmpps  ymm10, ymm1, [sqrt_ps], _CMP_LT_OQ ; mask x<sqrt(2)

    ; extract exponent
    vpsrld  ymm0, 23
    vpsubd  ymm0, [bias_ps]
    vcvtdq2ps ymm0, ymm0
    vaddps  ymm3, ymm0, ymm14

    ; restric mantissa to [1/sqrt(2), sqrt(2)) and adjust exponent
    vblendvps ymm3, ymm0, ymm10
    vblendvps ymm2, ymm1, ymm10

    vmulps ymm3, [log10_ps] ; log(2^e) = e*log10(2)

    ; r = (m-1)/(m+1)
    vsubps ymm1, ymm2, ymm14
    vaddps ymm2, ymm14
    vdivps ymm1, ymm2
    vmovaps ymm0, ymm1 ; ymm0 := r
    vmulps ymm1, ymm1  ; ymm1 := r^2

    ; evaluate polynomial
    vmovaps ymm2, [d3_ps]

    vfmadd213ps ymm2, ymm1, [d2_ps]
    vfmadd213ps ymm2, ymm1, [d1_ps]
    vfmadd213ps ymm2, ymm1, [d0_ps]

    vfmadd213ps ymm0, ymm2, ymm3

    ; Blend special return values into result
    vxorps ymm2, ymm2
    vsubps ymm2, ymm15
    vblendvps ymm0, ymm15, ymm11
    vblendvps ymm0, ymm2, ymm13
    vorps ymm0, ymm12

    ret





    section .data
    align 32
inf_pd:  times 4 dq __Infinity__
one_pd:  times 4 dq 1.0
hlf_pd:  times 4 dq 0.5
min_pd:  times 4 dq 0x10000000000000    ; smallest positive normalized double
sqrt_pd: times 4 dq 1.4142135623730950  ; sqrt(2)
bias_pd: times 8 dd 1023
idx_si:  dd 1, 3, 5, 7, 0, 2, 4, 6
log2_pd: times 4 dq 0.69314718055994530 ; log(2)
log10_pd: times 4 dq 0.30102999566398119801 ; log10(2)

e7_pd: times 4 dq 0.14797409006452383328
e6_pd: times 4 dq 0.15313891351138753105
e5_pd: times 4 dq 0.18183571218449789963
e4_pd: times 4 dq 0.22222198423351710583
e3_pd: times 4 dq 0.28571428744084542694
e2_pd: times 4 dq 0.39999999999405416728
e1_pd: times 4 dq 0.66666666666667362406
e0_pd: times 4 dq 2.0

p7_pd: times 4 dq 0.21581853366429265550
p6_pd: times 4 dq 0.22067486316401080381
p5_pd: times 4 dq 0.26234486231512765819
p4_pd: times 4 dq 0.32059829882592988381
p3_pd: times 4 dq 0.41219858868039366273
p2_pd: times 4 dq 0.57707801632799515800
p1_pd: times 4 dq 0.96179669392603739375
p0_pd: times 4 dq 2.88539008177792677400

d7_pd: times 4 dq 6.55239852489419433156e-2
d6_pd: times 4 dq 6.63683806940515153005e-2
d5_pd: times 4 dq 7.89763817383043048581e-2
d4_pd: times 4 dq 9.65096436155083448049e-2
d3_pd: times 4 dq 0.12408414009604452898
d2_pd: times 4 dq 0.17371779274846760321
d1_pd: times 4 dq 0.28952965460219881599
d0_pd: times 4 dq 0.86858896380650363333


inf_ps:  times 8 dd __Infinity__
one_ps:  times 8 dd 1.0
hlf_ps:  times 8 dd 0.5
min_ps:  times 8 dd 0x800000            ; smallest positive normalized value
sqrt_ps: times 8 dd 1.4142135623730950  ; sqrt(2)
bias_ps: times 8 dd 127
log2_ps: times 8 dd 0.69314718055994530 ; log(2)
log10_ps: times 8 dd 0.3010300099849700927734375 ; log10(2)

e3_ps: times 8 dd 0.2987057268619537353515625
e2_ps: times 8 dd 0.3997758924961090087890625
e1_ps: times 8 dd 0.666667759418487548828125
e0_ps: times 8 dd 2.0

p3_ps: times 8 dd 0.4448921680450439453125
p2_ps: times 8 dd 0.576037228107452392578125
p1_ps: times 8 dd 0.96180880069732666015625
p0_ps: times 8 dd 2.8853900432586669921875

d3_ps: times 8 dd 0.122495748102664947509765625
d2_ps: times 8 dd 0.17399297654628753662109375
d1_ps: times 8 dd 0.2895246446132659912109375
d0_ps: times 8 dd 0.868588984012603759765625
