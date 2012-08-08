@filename: maths.S

.text
.align 2
.global intdiv
.global intmod

@ input: r0 = numerator
@        r1 = divisor
@ output: r0 = result

intdiv:
	mov r2, r0
	mov r3, #0
loop:
	sub r2, r2, r1
	cmp r2, #0
	blt end
	add r3, r3, #1
	b loop
end:
	mov r0, r3
	bx lr


@ input: r0 = numerator
@        r1 = divisor
@ output: r0 = remainder

intmod:
	push {r4, r5, lr}
	mov r4, r0
	mov r5, r1
	bl intdiv
	mul r1, r0, r5  @r1= result * divisor
	sub r0, r4, r1
	pop {r4, r5, lr}
	bx lr


