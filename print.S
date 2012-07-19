.text
.align 2
.global print
.global println
.global printbool

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

.section .data
lfz:
	.asciz	"\n"
true:
	.asciz	"true"
false:
	.asciz	"false"
