.text
.align 2
.global print
.global println
.global printbool
.global printint

@ input: r0 = address of null terminated string


print:
	push	{r7}
	mov	r2, #0
printloop:
	ldrb	r1, [r0, r2]
	cmp	r1, #0
	addne	r2, r2, #1
	bne	printloop
	mov	r1, r0
	mov	r0, #1
	mov	r7, #4
	svc	0x00000000
	pop	{r7}
	bx	lr

println:
	push	{lr}
	bl	print
	ldr	r0, =lfz
	bl	print
	pop	{lr}
	bx	lr

@ input: r0 = 0 for false, non-zero for true
printbool:
	push	{lr}
	cmp	r0, #0
	ldreq	r0, =true
	ldrne	r0, =false
	bl	print
	pop	{lr}
	bx	lr

printint:
	push	{r5, lr}
	ldr	r3, =numbuf
	mov	r4, r0			@ store our number in r4

	mov	r5, #28			@ need to shift by 28 to get high order digit
printintloop:
	lsr	r0, r4, r5
	and	r0, r0, #0xF
	ldr	r2, =hex
	ldr	r0, [r2, r0]
	strb	r0, [r3]
	add	r3, r3, #1
	sub	r5, r5, #4
	cmp	r5, #0
	bge	printintloop

	ldr	r0, =numbuf
	bl	print
	pop	{r5, lr}
	bx	lr

.section .data
lfz:
	.asciz	"\n"
true:
	.asciz	"true"
false:
	.asciz	"false"
hex:
	.asciz	"0123456789ABCDEF"
numbuf:
	.asciz	"00000000\n"
