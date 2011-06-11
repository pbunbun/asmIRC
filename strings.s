.text
    .global strlen
    .global itoa

#itoa(long value, char* str)
#As the C function (minus the base parameter), but presumably much worse
#Just assume enough space for it (like 20 bytes max), leave that to the caller
itoa:
	push %rbp
	movq %rsp, %rbp
	
	movq 16(%rbp), %rcx	#Load the value into %rcx
	movq 24(%rbp), %rdi	#Start of the output string
	movq $1000000000000000000, %rbx	#Really large power of 10 (largest that can divide into a signed 64-bit value)
	movq $10, %rsi						#The base
	
    #Is it 0?
	cmpq $0, %rcx
	jl minus
	jg pos
	movb $'0', (%rdi)
	inc %rdi
	jmp end
	
	#Add a minus sign, negate it and then treat as positive
	minus:
		movb $'-', (%rdi)
		inc %rdi
		not %rcx
		inc %rcx
		
	pos:
	#Skip leading zeroes
	skip0:
		cmp %rbx, %rcx
		jge iter			#RCX >= RBX?
		xor %rdx, %rdx
		movq %rbx, %rax		#rdx:rax = %rbx
		
		divq %rsi			#Divide %rbx by base
		movq %rax, %rbx		#Result into %rbx
		jmp skip0
	
	#Then actually loop down each digit place
	iter:
		cmpq $0, %rbx
		je end
		xor %rdx, %rdx		#Value (%rcx) into %rdx:rax
		movq %rcx, %rax
	
		divq %rbx			#Divide by %rbx
		movq %rdx, %rcx		#Remainder back into value
	
		addb $0x30, %al		#Ascii value of the quotient
		movb %al, (%rdi)	#Into the string at current location
		inc %rdi
		
		xor %rdx, %rdx		#Now divide %rbx by the base, then back to iter
		movq %rbx, %rax
		divq %rsi
		movq %rax, %rbx
	
		jmp iter
	
	end:
		movb $0, (%rdi)		#Null byte
		movq 24(%rbp), %rax	#Return the start of string
	
	movq %rbp, %rsp
	pop %rbp
	ret

strlen:
	push %rbp
	movq %rsp, %rbp
	
	movq 16(%rbp), %rdi	#Use %rdi for the string address
	movq $0, %rax		#This is where we count
	
	cmpLen:
	cmpb $0, (%rdi)
	je retLen
	inc %rdi
	inc %rax
	jmp cmpLen
	
	retLen:
	movq %rbp, %rsp
	pop %rbp
	ret
