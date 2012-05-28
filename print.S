.text
.align 2
.global print

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
