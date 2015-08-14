    global escape_test_ps
    global escape_test_pd
    global bulb_test_ps
    global bulb_test_pd
    global write_orbits_ps
    global write_orbits_pd

    section .text


    align 16
escape_test_ps:
    ; int escape_test_ps(const float* cr, const float* ci, uint32_t* ic,
    ;     uint64_t size, uint32_t maxiter, float rad)
    ; For each complex value cr[n] + i*ci[n] iterates over the complex quadratic
    ; polynomial
    ; z_n+1 = z_n^2 + c, z_0 = 0
    ; and writes the iteration count where the point escapes the cricle of
    ; radius rad to ic[n]. If the point doesn't escape within maxiter iterations
    ; that value is written instead.
    ; The number of points (size) must be a multiple of 8.
    xor rax, rax

    ; cr is nullptr
    sub rax, 1
    test rdi, rdi
    jz .exit

    ; ci is nullptr
    sub rax, 1
    test rsi, rsi
    jz .exit

    ; ic is nullptr
    sub rax, 1
    test rdx, rdx
    jz .exit

    ; size is not 0 mod 8
    sub rax, 1
    test rcx, 0x07
    jnz .exit


    vbroadcastss ymm0, xmm0
    vmulps  ymm0, ymm0 ; square the radius to later compare with the
                       ; squared norm

    mov r9, r8
    mov r8, rcx
    shl r8, 2
    xor rax,rax

.outer_loop:
    vxorps  ymm1, ymm1      ; z_r
    vxorps  ymm2, ymm2      ; z_i
    vmovups ymm3, [rdi+rax] ; c_r
    vmovups ymm4, [rsi+rax] ; c_i
    vxorps  ymm5, ymm5      ; escape counter
    vxorps  ymm8, ymm8
    vxorps  ymm9, ymm9


    mov rcx, r9

    ; calculates a single iteration of the complex polynomial
    ; z_n+1 = z_n^2 + c = z_r^2 - z_i^2 + c_r + i(2*z_r*z_i + c_i)
    ; and compares with the escape radius.
    ; Note that the squares z_r^2 and z_i^2 are actually calculated _after_ the
    ; main calculation. Since they start out as 0 they are already squared in
    ; the first iteration and subseqent iterations can use the value of the
    ; previous one. This saves repeating two multiplications for the squared norm.
.inner_loop:
    vmulps ymm7, ymm1, ymm2
    vaddps ymm7, ymm7
    vsubps ymm1, ymm8, ymm9
    vaddps ymm1, ymm3
    vaddps ymm2, ymm7, ymm4

    vmulps ymm8, ymm1, ymm1
    vmulps ymm9, ymm2, ymm2
    vaddps ymm7, ymm8, ymm9
    vcmpleps ymm7, ymm0
    vpsubd ymm5, ymm7

    loop .inner_loop

    vmovups [rdx+rax], ymm5

    add rax, 0x20
    cmp rax, r8
    jl .outer_loop

    xor rax, rax
.exit:
    ret





    align 16
escape_test_pd:
    ; int escape_test_pd(const double* cr, const double* ci, uint64_t* ic,
    ;     uint64_t size, uint64_t maxiter, double rad)
    ; For each complex value cr[n] + i*ci[n] iterates over the complex quadratic
    ; polynomial
    ; z_n+1 = z_n^2 + c, z_0 = 0
    ; and writes the iteration count where the point escapes the cricle of
    ; radius rad to ic[n]. If the point doesn't escape within maxiter iterations
    ; that value is written instead.
    ; The number of points (size) must be a multiple of 4.
    xor rax, rax

    ; cr is nullptr
    sub rax, 1
    test rdi, rdi
    jz .exit

    ; ci is nullptr
    sub rax, 1
    test rsi, rsi
    jz .exit

    ; ic is nullptr
    sub rax, 1
    test rdx, rdx
    jz .exit

    ; size is not 0 mod 4
    sub rax, 1
    test rcx, 0x03
    jnz .exit


    vbroadcastsd ymm0, xmm0
    vmulpd  ymm0, ymm0 ; square the radius to later compare with the
                       ; squared norm

    mov r9, r8
    mov r8, rcx
    shl r8, 3
    xor rax,rax

.outer_loop:
    vxorps  ymm1, ymm1      ; z_r
    vxorps  ymm2, ymm2      ; z_i
    vmovups ymm3, [rdi+rax] ; c_r
    vmovups ymm4, [rsi+rax] ; c_i
    vxorps  ymm5, ymm5      ; escape counter
    vxorps  ymm8, ymm8
    vxorps  ymm9, ymm9


    mov rcx, r9

    ; calculates a single iteration of the complex polynomial
    ; z_n+1 = z_n^2 + c = z_r^2 - z_i^2 + c_r + i(2*z_r*z_i + c_i)
    ; and compares with the escape radius.
    ; Note that the squares z_r^2 and z_i^2 are actually calculated _after_ the
    ; main calculation. Since they start out as 0 they are already squared in
    ; the first iteration and subseqent iterations can use the value of the
    ; previous one. This saves repeating two multiplications for the squared norm.
.inner_loop:
    vmulpd ymm7, ymm1, ymm2
    vaddpd ymm7, ymm7
    vsubpd ymm1, ymm8, ymm9
    vaddpd ymm1, ymm3
    vaddpd ymm2, ymm7, ymm4

    vmulpd ymm8, ymm1, ymm1
    vmulpd ymm9, ymm2, ymm2
    vaddpd ymm7, ymm8, ymm9
    vcmplepd ymm7, ymm0
    vpsubd ymm5, ymm7

    loop .inner_loop

    vmovups [rdx+rax], ymm5

    add rax, 0x20
    cmp rax, r8
    jl .outer_loop

    xor rax, rax
.exit:
    ret





    align 16
bulb_test_ps:
    ; int bulb_test_ps(const float* cr, const float* ci,
    ;                  uint32_t* im, uint64_t size)
    ; Tests whether the point defined by cr[n] + i*ci[n] is in either the main
    ; cardoid or the period-2 bulb or not.
    xor rax, rax

    ; cr is nullptr
    sub rax, 1
    test rdi, rdi
    jz .exit

    ; ci is nullptr
    sub rax, 1
    test rsi, rsi
    jz .exit

    ; im is nullptr
    sub rax, 1
    test rdx, rdx
    jz .exit

    ; size is not 0 mod 8
    sub rax, 1
    test rcx, 0x07
    jnz .exit

    vmovaps ymm2, [ovfour_ps]
    vmovaps ymm3, [ovsixteen_ps]
    vmovaps ymm4, [one_ps]

.loop:
    vmovups ymm0, [rdi+4*rcx-4]
    vmovups ymm1, [rsi+4*rcx-4]

    vmulps ymm1, ymm1
    vmulps ymm8, ymm2, ymm1

    vsubps ymm5, ymm0, ymm2
    vmulps ymm6, ymm5, ymm5
    vaddps ymm6, ymm1
    vaddps ymm7, ymm6, ymm5
    vmulps ymm6, ymm7
    vcmpltps ymm6, ymm8

    vaddps ymm7, ymm0, ymm4
    vmulps ymm7, ymm7
    vaddps ymm7, ymm1
    vcmpltps ymm7, ymm3

    vpor ymm7, ymm6
    vmovups [rdx+4*rcx-4], ymm7

    loop .loop

    xor rax, rax
.exit:
    ret





    align 16
bulb_test_pd:
    ; int bulb_test_pd(const double* cr, const double* ci,
    ;                  uint64_t* im, uint64_t size)
    ; Tests whether the point defined by cr[n] + i*ci[n] is in either the main
    ; cardoid or the period-2 bulb or not.
    xor rax, rax

    ; cr is nullptr
    sub rax, 1
    test rdi, rdi
    jz .exit

    ; ci is nullptr
    sub rax, 1
    test rsi, rsi
    jz .exit

    ; im is nullptr
    sub rax, 1
    test rdx, rdx
    jz .exit

    ; size is not 0 mod 8
    sub rax, 1
    test rcx, 0x03
    jnz .exit

    vmovaps ymm2, [ovfour_ps]
    vmovaps ymm3, [ovsixteen_ps]
    vmovaps ymm4, [one_ps]

.loop:
    vmovups ymm0, [rdi+4*rcx-4]
    vmovups ymm1, [rsi+4*rcx-4]

    vmulpd ymm1, ymm1
    vmulpd ymm8, ymm2, ymm1

    vsubpd ymm5, ymm0, ymm2
    vmulpd ymm6, ymm5, ymm5
    vaddpd ymm6, ymm1
    vaddpd ymm7, ymm6, ymm5
    vmulpd ymm6, ymm7
    vcmpltpd ymm6, ymm8

    vaddpd ymm7, ymm0, ymm4
    vmulpd ymm7, ymm7
    vaddpd ymm7, ymm1
    vcmpltpd ymm7, ymm3

    vpor ymm7, ymm6
    vmovups [rdx+4*rcx-4], ymm7

    loop .loop

    xor rax, rax
.exit:
    ret





    align 16
write_orbits_ps:
    ; int write_orbits_ps(const float* cr, const float* ci, uint64_t size,
    ;     uint32_t maxiter, float min_r, float max_r, float min_i, float max_i,
    ;     uint32_t* img, uint32_t width, uint32_t height);
    ; For each 0 <= n < size, iterate at most maxiter times over the
    ; complex polynomial z_n+1 = z_n^2 + c
    ; with z_0 = 0 and c = cr[n] + i*ci[n].
    ; For each z_(n>0), if z_n falls into the region defined by
    ; [min_r, max_r] x [min_i, max_i], increase the corresponding pixel in
    ; the image at img with dimensions width x height.
    ; Size must be a multiple of 8.

    ; rdi     -> cr
    ; rsi     -> ci
    ; rdx     -> size
    ; rcx     -> maxiter
    ; r8      -> img
    ; r9      -> width
    ; [rsp+8] -> height (r10)
    ; rax -> outer loop counter

    xor rax, rax

    ; cr is nullptr
    dec rax
    test rdi, rdi
    jz .exit

    ; ci is nullptr
    dec rax
    test rsi, rsi
    jz .exit

    ; img is nullptr
    dec rax
    test r8, r8
    jz .exit

    ; size is not 0 mod 8
    dec rax
    test rdx, 0x07
    jnz .exit

    ; save old rounding mode and set current one to round to zero
    sub       rsp, 8
    vstmxcsr [rsp]
    vstmxcsr [rsp+4]
    or dword [rsp+4], 3 << 13
    vldmxcsr [rsp+4]

    mov r10d, [rsp+16]

    ; calculate scaling for C -> image
    vbroadcastss ymm0, xmm0
    vbroadcastss ymm1, xmm1
    vbroadcastss ymm2, xmm2
    vbroadcastss ymm3, xmm3

    vsubps ymm4, ymm1, ymm0
    vsubps ymm5, ymm3, ymm2
    vcvtsi2ss xmm6, r9d
    vcvtsi2ss xmm7, r10d
    vbroadcastss ymm6, xmm6
    vbroadcastss ymm7, xmm7
    vdivps ymm4, ymm6, ymm4
    vdivps ymm5, ymm7, ymm5

    vmovd xmm6, r9d
    vpbroadcastd ymm6, xmm6

    shl rdx, 2
    xor rax, rax

.outer_loop:
    vxorps  ymm7,  ymm7
    vxorps  ymm8,  ymm8
    vmovups ymm9,  [rdi+rax]
    vmovups ymm10, [rsi+rax]

    xor r11, r11
.inner_loop:
    vmulps ymm11, ymm7, ymm8
    vaddps ymm11, ymm11
    vmulps ymm12, ymm7, ymm7
    vmulps ymm13, ymm8, ymm8
    vsubps ymm12, ymm13
    vaddps ymm8, ymm11, ymm10
    vaddps ymm7, ymm12, ymm9

    vcmpleps ymm11, ymm0, ymm7
    vcmpgtps ymm12, ymm1, ymm7
    vandps ymm11, ymm12
    vcmpleps ymm12, ymm2, ymm8
    vandps ymm11, ymm12
    vcmpgtps ymm12, ymm3, ymm8
    vandps ymm11, ymm12
    vmovups [rsp-0x40], ymm11

    vsubps ymm13, ymm7, ymm0
    vsubps ymm14, ymm8, ymm2
    vmulps ymm13, ymm4
    vmulps ymm14, ymm5

    vcvtps2dq ymm13, ymm13
    vcvtps2dq ymm14, ymm14
    vpmulld ymm14, ymm6
    vpaddd  ymm14, ymm13
    vmovups [rsp-0x20], ymm14

    mov r9d,  [rsp-0x40]
    mov r10d, [rsp-0x20]
    test r9d, r9d
    jz .S1
    inc dword [r8+4*r10]
.S1:mov r9d,  [rsp-0x3c]
    mov r10d, [rsp-0x1c]
    test r9d, r9d
    jz .S2
    inc dword [r8+4*r10]
.S2:mov r9d,  [rsp-0x38]
    mov r10d, [rsp-0x18]
    test r9d, r9d
    jz .S3
    inc dword [r8+4*r10]
.S3:mov r9d,  [rsp-0x34]
    mov r10d, [rsp-0x14]
    test r9d, r9d
    jz .S4
    inc dword [r8+4*r10]
.S4:mov r9d,  [rsp-0x30]
    mov r10d, [rsp-0x10]
    test r9d, r9d
    jz .S5
    inc dword [r8+4*r10]
.S5:mov r9d,  [rsp-0x2c]
    mov r10d, [rsp-0x0c]
    test r9d, r9d
    jz .S6
    inc dword [r8+4*r10]
.S6:mov r9d,  [rsp-0x28]
    mov r10d, [rsp-0x08]
    test r9d, r9d
    jz .S7
    inc dword [r8+4*r10]
.S7:mov r9d,  [rsp-0x24]
    mov r10d, [rsp-0x04]
    test r9d, r9d
    jz .S8
    inc dword [r8+4*r10]
.S8:

    inc r11
    cmp r11, rcx
    jl .inner_loop

    add rax, 0x20
    cmp rax, rdx
    jl .outer_loop

.end:
    ; restore rounding mode
    vldmxcsr [rsp]
    add       rsp, 8

    xor rax, rax
.exit:
    ret





    align 16
write_orbits_pd:
    ; int write_orbits_pd(const double* cr, const double* ci, uint64_t size,
    ;     uint64_t maxiter, double min_r, double max_r, double min_i, double max_i,
    ;     uint64_t* img, uint64_t width, uint64_t height);
    ; For each 0 <= n < size, iterate at most maxiter times over the
    ; complex polynomial z_n+1 = z_n^2 + c
    ; with z_0 = 0 and c = cr[n] + i*ci[n].
    ; For each z_(n>0), if z_n falls into the region defined by
    ; [min_r, max_r] x [min_i, max_i], increase the corresponding pixel in
    ; the image at img with dimensions width x height.
    ; Size must be a multiple of 4.
    ; Width and height of the image must be smaller than 2^31.

    ; rdi     -> cr
    ; rsi     -> ci
    ; rdx     -> size
    ; rcx     -> maxiter
    ; r8      -> img
    ; r9      -> width
    ; [rsp+8] -> height (r10)
    ; rax -> outer loop counter

    xor rax, rax

    ; cr is nullptr
    dec rax
    test rdi, rdi
    jz .exit

    ; ci is nullptr
    dec rax
    test rsi, rsi
    jz .exit

    ; img is nullptr
    dec rax
    test r8, r8
    jz .exit

    ; size is not 0 mod 4
    dec rax
    test rdx, 0x03
    jnz .exit

    ; save old rounding mode and set current one to round to zero
    sub       rsp, 8
    vstmxcsr [rsp]
    vstmxcsr [rsp+4]
    or dword [rsp+4], 3 << 13
    vldmxcsr [rsp+4]

    mov r10d, [rsp+16]

    ; calculate scaling for C -> image
    vbroadcastsd ymm0, xmm0
    vbroadcastsd ymm1, xmm1
    vbroadcastsd ymm2, xmm2
    vbroadcastsd ymm3, xmm3

    vsubpd ymm4, ymm1, ymm0
    vsubpd ymm5, ymm3, ymm2
    vcvtsi2sd xmm6, r9d
    vcvtsi2sd xmm7, r10d
    vbroadcastsd ymm6, xmm6
    vbroadcastsd ymm7, xmm7
    vdivpd ymm4, ymm6, ymm4
    vdivpd ymm5, ymm7, ymm5

    vmovd xmm6, r9d
    vpbroadcastd ymm6, xmm6

    shl rdx, 1
    xor rax, rax

.outer_loop:
    vxorps  ymm7,  ymm7
    vxorps  ymm8,  ymm8
    vmovups ymm9,  [rdi+rax]
    vmovups ymm10, [rsi+rax]

    xor r11, r11
.inner_loop:
    vmulpd ymm11, ymm7, ymm8
    vaddpd ymm11, ymm11
    vmulpd ymm12, ymm7, ymm7
    vmulpd ymm13, ymm8, ymm8
    vsubpd ymm12, ymm13
    vaddpd ymm8, ymm11, ymm10
    vaddpd ymm7, ymm12, ymm9

    vcmplepd ymm11, ymm0, ymm7
    vcmpgtpd ymm12, ymm1, ymm7
    vandps ymm11, ymm12
    vcmplepd ymm12, ymm2, ymm8
    vandps ymm11, ymm12
    vcmpgtpd ymm12, ymm3, ymm8
    vandps ymm11, ymm12
    vmovups [rsp-0x40], ymm11

    vsubpd ymm13, ymm7, ymm0
    vsubpd ymm14, ymm8, ymm2
    vmulpd ymm13, ymm4
    vmulpd ymm14, ymm5
    vcvtpd2dq xmm13, ymm13
    vcvtpd2dq xmm14, ymm14
    vpmovsxdq ymm13, xmm13
    vpmovsxdq ymm14, xmm14

    vpmuldq ymm14, ymm6
    vpaddq  ymm14, ymm13
    vmovups [rsp-0x20], ymm14

    mov r9,  [rsp-0x40]
    mov r10, [rsp-0x20]
    test r9, r9
    jz .S1
    inc qword [r8+r10]
.S1:mov r9,  [rsp-0x38]
    mov r10, [rsp-0x18]
    test r9, r9
    jz .S2
    inc qword [r8+r10]
.S2:mov r9d,  [rsp-0x30]
    mov r10d, [rsp-0x10]
    test r9d, r9d
    jz .S3
    inc qword [r8+r10]
.S3:mov r9d,  [rsp-0x28]
    mov r10d, [rsp-0x08]
    test r9d, r9d
    jz .S4
    inc qword [r8+r10]
.S4:

    inc r11
    cmp r11, rcx
    jl .inner_loop

    add rax, 0x20
    cmp rax, rdx
    jl .outer_loop

.end:
    ; restore rounding mode
    vldmxcsr [rsp]
    add       rsp, 8

    xor rax, rax
.exit:
    ret





    section .data
    align 32
ovfour_ps:    times 8 dd 0.25
ovsixteen_ps: times 8 dd 0.0625
one_ps:       times 8 dd 1.0
