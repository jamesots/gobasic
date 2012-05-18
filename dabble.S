@filename: dabble.S

.text
.align 2
.global doubledabble

@ input: r0 = number to convert
@ output: r0 = address of null terminated string (owned by this code)

@ based on the C implementation in Wikipedia

@    int nbits = 32;         /* length of arr in bits */
@    int nscratch = 10; // nbits/3;   /* length of scratch in bytes */
@    char *scratch = calloc(1 + nscratch, sizeof *scratch);  11 chars
@    int i, j, k;
@    int smin = 8; // nscratch-2;    /* speed optimization */

doubledabble:
	push	{r3, r4, r5, r6, r7, r8, r9, r10, r11}
	mov	r10, #8          @ r10 = smin
	ldr	r1, =dabble
	cmp	r0, #0
	bge	nonnegative
	mov	r2, #'-'
	str	r2, [r1]	  @ store minus sign
	add	r1, r1, #1    @ reserve space for it
	mov	r2, #0
	sub	r0, r2, r0    @ make number positive	
nonnegative:

@zero the memory
	mov	r2, #0
	str	r2, [r1]
	str	r2, [r1, #4]
	str	r2, [r1, #8]
@        for (j=0; j < 32; ++j) {
	mov	r4, #31 
loopj:
@            /* This bit will be shifted in on the right. */
@            int shifted_in = (arr[i] & (1 << (31-j)))? 1: 0;
	mov	r5, r0
	mov	r6, #1
	lsl	r6, r4
	ands	r6, r6, r5
	moveq	r7, #0     @ r7 = shifted_in
	movne	r7, #1
@            /* Add 3 everywhere that scratch[k] >= 5. */
@            for (k=smin; k < nscratch; ++k)
	mov	r8, r10      @ r8 = k
loopk:
	cmp	r8, #10
	bge	pastloopk
@              scratch[k] += (scratch[k] >= 5)? 3: 0;
	ldrb	r9, [r1, r8]
	cmp	r9, #5
	blt	afterinc
	add	r9, #3
	strb	r9, [r1, r8] 
afterinc:

	add	r8, r8, #1
	b	loopk
pastloopk:
 
@            /* Shift scratch to the left by one position. */
@            if (scratch[smin] >= 8)
@              smin -= 1;
	ldrb	r9, [r1, r10]
	cmp	r9, #8
	subge	r10, r10, #1


@            for (k=smin; k < nscratch-1; ++k) {
	mov	r8, r10
loopk2:
	cmp	r8, #9
	bge	pastloopk2
@                scratch[k] <<= 1;
	ldrb	r9, [r1, r8]
	lsl	r9, r9, #1
@                scratch[k] &= 0xF;
	and	r9, r9, #0xF
@                scratch[k] |= (scratch[k+1] >= 8);
	add	r11, r8, #1
	ldrb	r11, [r1, r11]
	cmp	r11, #8
	orrge	r9, #1
	strb	r9, [r1, r8]
@            }
	add	r8, r8, #1
	b	loopk2
pastloopk2:
 
@            /* Shift in the new bit from arr. */
@            scratch[nscratch-1] <<= 1;
	ldrb	r9, [r1, #9]
	lsl	r9, r9, #1
@            scratch[nscratch-1] &= 0xF;
	and	r9, r9, #0xF
@            scratch[nscratch-1] |= shifted_in;
	orr	r9, r9, r7
	strb	r9, [r1, #9]
@        }
	subs	r4, r4, #1
	bge	loopj
 
@    /* Remove leading zeros from the scratch space. */
@    for (k=0; k < nscratch-1; ++k)
	mov	r8, #0
loopk3:
	cmp	r8, #9
	bgt	pastloopk3
@      if (scratch[k] != 0) break;
	ldrb	r9, [r1, r8]
	cmp	r9, #0
	bne	pastloopk3
	add	r8, r8, #1
	b	loopk3
pastloopk3:

@    nscratch -= k;
	mov	r11, #10
	sub	r11, r11, r8

@    memmove(scratch, scratch+k, nscratch+1);
	mov	r3, r1          @ dest
	add	r4, r1, r8      @ src
	add	r8, r11, #1     @ count
loopmove:
	cmp	r8, #0
	beq	pastloopmove
	ldrb	r9, [r4]
	strb	r9, [r3]
	add	r3, r3, #1
	add	r4, r4, #1
	sub	r8, r8, #1
	b	loopmove
pastloopmove:

 
@    /* Convert the scratch space from BCD digits to ASCII. */
@    for (k=0; k < nscratch; ++k)
	mov	r8, #0
loopk4:
	cmp	r8, r11
	bge	pastloopk4
@      scratch[k] += '0';
	ldrb	r9, [r1, r8]
	add	r9, r9, #'0'
	strb	r9, [r1, r8]
	add	r8, r8, #1
	b	loopk4
pastloopk4:
	ldr	r0, =dabble
	pop	{r3, r4, r5, r6, r7, r8, r9, r10, r11}
	bx	lr


.align 2
.section .data
dabble:
	.ascii	"............" @ 11 bytes
