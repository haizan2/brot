    global xorshift128_next
    global xorshift1024_next
    global fill_canonical128_ps
    global fill_canonical128_pd

    section .text





    align 16
xorshift128_next:
    vmovupd ymm0, [rdi]
    vmovupd ymm1, [rdi+0x20]
    vmovupd [rdi], ymm1
    vpsllq  ymm2, ymm0, 23
    vxorps  ymm2, ymm0
    vpsrlq  ymm0, ymm2, 17
    vxorps  ymm2, ymm1
    vxorps  ymm2, ymm0
    vpsrlq  ymm0, ymm1, 26
    vxorps  ymm2, ymm0
    vmovupd [rdi+0x20], ymm2
    vpaddq  ymm0, ymm1, ymm2
    ret





    align 16
xorshift1024_next:
    mov      rax, [rdi+0x200]
    vmovdqu  ymm0, [rdi+rax]
    add      rax, 0x20
    and      rax, 0x1e0
    vmovdqu  ymm1, [rdi+rax]
    mov      [rdi+0x200], rax

    vpsllq   ymm2, ymm1, 31
    vpxor    ymm1, ymm2
    vpsrlq   ymm3, ymm0, 30
    vpxor    ymm0, ymm3
    vpsrlq   ymm2, ymm1, 11
    vpxor    ymm1, ymm2
    vpxor    ymm0, ymm1
    vmovdqu  [rdi+rax], ymm0

    vmovdqa  ymm2, [xs1024lo]
    vpsrlq   ymm1, ymm0, 32
    vpmuludq ymm1, ymm2
    vpmuludq ymm3, ymm0, [xs1024hi]
    vpaddq   ymm1, ymm3
    vpmuludq ymm4, ymm0, ymm2
    vpsllq   ymm1, 32
    vpaddq   ymm0, ymm1, ymm4
    ret





    align 16
fill_canonical128_ps:
    ; rdi: pointer to float array to be filled
    ; rsi: size of array to be filled
    ; rdx: xorshift128 state pointer

    ; load rng state
    vmovups ymm0, [rdx]       ; ymm0 <- s1
    vmovups ymm1, [rdx+0x20]  ; ymm1 <- s0
    vmovaps ymm4, [fc128_ps]
    vmovaps ymm8, [fc128_32]
    vmovaps ymm9, [fc128_and_ps]

    ; less than 8 remaining?
    cmp rsi, 8
    jl .Lfc128pslast

    ; 8 loop
.Lfc128loop8:
    call fill_canonical128_ps_next

    vmovups [rdi], ymm3
    add rdi, 0x20
    sub rsi, 8

    cmp rsi, 8
    jge .Lfc128loop8

    ; last <8 elements
.Lfc128pslast:
    test rsi, rsi
    jz .Lfc128psend
    call fill_canonical128_ps_next

    vmovd xmm2, esi
    vpbroadcastd ymm2, xmm2
    vpcmpgtd ymm2, ymm2, ymm8
    vpmaskmovd [rdi], ymm2, ymm3

.Lfc128psend:
    ; save rng state
    vmovups [rdx], ymm0
    vmovups [rdx+0x20], ymm1
    ret

    align 16
    ; advance rng state and return floats
fill_canonical128_ps_next:
    ; s1 ^= s1 << 23
    vpsllq ymm2, ymm0, 23
    vxorps ymm2, ymm0

    ; s1 ^= s0 ^ (s1 >> 17) ^ (s0 >> 26)
    vpsrlq ymm0, ymm2, 17
    vxorps ymm2, ymm1
    vxorps ymm2, ymm0

    ; s1 ^= s0 >> 26
    vpsrlq ymm0, ymm1, 26
    vxorps ymm2, ymm0

    ; next = s1 + s0
    vpaddq ymm3, ymm2, ymm1

    ; xchg(s1, s0)
    vmovaps ymm0, ymm1
    vmovaps ymm1, ymm2

    ; next = float(next) * 2**-32
    vxorps    ymm2, ymm2
    vcvtdq2ps ymm5, ymm3
    vpcmpgtd  ymm2, ymm3
    vpsrld    ymm6, ymm3, 1
    vandps    ymm3, ymm9
    vorps     ymm3, ymm6
    vcvtdq2ps ymm3, ymm3
    vaddps    ymm3, ymm3
    vblendvps ymm3, ymm5, ymm3, ymm2

    vpsubd    ymm3, ymm4
    ret





    align 16
fill_canonical128_pd:
    ; rdi: pointer to double array to be filled
    ; rsi: size of array to be filled
    ; rdx: xorshift128 state pointer

    ; load rng state
    vmovups ymm0, [rdx]       ; ymm0 <- s1
    vmovups ymm1, [rdx+0x20]  ; ymm1 <- s0
    vmovaps ymm4, [fc128_pd]
    vmovaps ymm8, [fc128_64]
    vmovaps ymm9, [fc128_and_pd]

    ; space to spill two ymm registers on the stack
    sub rsp, 0x20

    ; less than 4 remaining?
    cmp rsi, 4
    jl .Lfc128pdlast

    ; 4 loop
.Lfc128loop4:
    call fill_canonical128_pd_next

    vmovups [rdi], ymm3
    add rdi, 0x20
    sub rsi, 4

    cmp rsi, 4
    jge .Lfc128loop4

    ; last <4 elements
.Lfc128pdlast:
    test rsi, rsi
    jz .Lfc128pdend
    call fill_canonical128_pd_next

    vmovq xmm2, rsi
    vpbroadcastq ymm2, xmm2
    vpcmpgtq ymm2, ymm2, ymm8
    vpmaskmovq [rdi], ymm2, ymm3

.Lfc128pdend:
    ; save rng state
    vmovups [rdx], ymm0
    vmovups [rdx+0x20], ymm1
    ; restore stack pointer
    add rsp, 0x20

    ret

    align 16
    ; advance rng state and return doubles
fill_canonical128_pd_next:
    ; s1 ^= s1 << 23
    vpsllq ymm2, ymm0, 23
    vxorps ymm2, ymm0

    ; s1 ^= s0 ^ (s1 >> 17) ^ (s0 >> 26)
    vpsrlq ymm0, ymm2, 17
    vxorps ymm2, ymm1
    vxorps ymm2, ymm0

    ; s1 ^= s0 >> 26
    vpsrlq ymm0, ymm1, 26
    vxorps ymm2, ymm0

    ; next = s1 + s0
    vpaddq ymm3, ymm2, ymm1

    ; xchg(s1, s0)
    vmovaps ymm0, ymm1
    vmovaps ymm1, ymm2

    ; next = double(next) * 2**-64
    vxorps     ymm2,  ymm2
    vpcmpgtq   ymm2,  ymm3
    vmovups    [rsp+0x08], ymm3
    vpsrlq     ymm6,  ymm3, 1
    vandps     ymm3,  ymm9
    vorps      ymm3,  ymm6
    vpmaskmovq [rsp+0x08], ymm2, ymm3

    vcvtsi2sd xmm3, qword [rsp+0x08]
    vmovq     [rsp+0x08], xmm3
    vcvtsi2sd xmm5, qword [rsp+0x10]
    vmovq     [rsp+0x10], xmm5
    vcvtsi2sd xmm6, qword [rsp+0x18]
    vmovq     [rsp+0x18], xmm6
    vcvtsi2sd xmm7, qword [rsp+0x20]
    vmovq     [rsp+0x20], xmm7

    vmovups ymm5, [rsp+0x08]
    vaddpd  ymm3, ymm5, ymm5
    vblendvpd ymm3, ymm5, ymm3, ymm2

    vpsubq ymm3, ymm4
    ret



    section .data
    align 32
xs1024hi: times 4 dq 0x00000000106689d4
xs1024lo: times 4 dq 0x000000005497fdb5

fc128_ps: times 8 dd 32<<23
fc128_32: dd 0, 1, 2, 3, 4, 5, 6, 7
fc128_and_ps:times 8 dd 1

fc128_pd: times 4 dq 64<<52
fc128_64: dq 0, 1, 2, 3
fc128_and_pd:times 4 dq 1
