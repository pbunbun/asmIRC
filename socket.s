.data

sockfd:
    .quad 0

sockaddr:
    .word 2
    .byte 0x1a, 0x0b
    .byte 128, 39, 65, 226
    .quad 0

ident:
	.ascii "USER asmIRC localhost localhost :asmIRC\nNICK asmIRC\n\0"
joinStr:
	.ascii "JOIN #asmIRCtest\n\0"

ping:
	.ascii "PING"
join:
	.ascii ":asm"

msg:
    .fill 512, 1, 0

.text
    .global _start

#Connects to the server
#Returns -1 on error, 0 on success
#Takes &sockfd and &sockaddr
connect:
    push %rbp
    movq %rsp, %rbp

    movq $41, %rax  #sys_socket
    movq $2, %rdi   #Family
    movq $1, %rsi   #Type
    movq $0, %rdx   #Protocol
    syscall

    #Check for error and return -1 if error, else update sockfd
    cmp $-1, %rax
    je retConn
    movq 16(%rbp), %rbx
    movq %rax, (%rbx)

    movq $42, %rax      #sys_connect
    movq (%rbx), %rdi   #sockfd
    movq 24(%rbp), %rsi #&sockaddr
    movq $16, %rdx      #sizeof(sockaddr)
    syscall

    #Check for error and retrun -1 if error, else 0
    cmp $-1, %rax
    je retConn
    xor %rax, %rax

    retConn:
    movq %rbp, %rsp
    pop %rbp
    ret

#Reads up to a newline character (including it at the end, we're going to want one after we print it anyway)
#Disregards \r to simplify things
#Returns the count of bytes read, doesn't handle errors for now
#Takes sockfd and &buff
readLine:
    push %rbp
    movq %rsp, %rbp

    subq $5, %rsp
    movl $0, -4(%rbp)   #Initialise Count
    movb $0, -5(%rbp)   #Space for the byte we're reading
    
    getByte:
    movq $0, %rax   #sys_read
    movq 16(%rbp), %rdi #sockfd
    movq %rbp, %rsi     #Set up this to point to temp byte
    subq $5, %rsi
    movq $1, %rdx       #Count
    syscall

    movb -5(%rbp), %cl  #Move byte read into cl

    cmpb $'\r', %cl   #Disregard \r
    je getByte
    
    movq 24(%rbp), %rsi #%rsi to point to (buff + count)
    addl -4(%rbp), %esi
    movb %cl, (%rsi)    #Move byte to end
    incl -4(%rbp)       #Inc count
    cmpb $'\n', %cl       #\n means we're done
    jne getByte
    
    #Now add a null byte
    inc %rsi
    movb $0, (%rsi)

    xor %rax, %rax
    movl -4(%rbp), %eax
    movq %rbp, %rsp
    pop %rbp
    ret
    
#Writes a string to sockfd, returns number of characters written
#Calls strlen on the string to get its length
#Takes sockfd and &msg.
writeString:
	push %rbp
	movq %rsp, %rbp
	
	pushq 24(%rbp)	#Get string length
	call strlen
	pop %rsi		#Just pop address right into the register write() uses for *buf
	movq 16(%rbp), %rdi	#Now the fd
	movq %rax, %rdx		#Finally the length
	movq $1, %rax
	syscall				#Write it
	
	movq %rbp, %rsp
	pop %rbp
	ret

_start:
    #Call Connect(&sockfd, &sockaddr)
    push $sockaddr
    push $sockfd
    call connect
    addq $16, %rsp  #Get rid of the parameters

	cmpq $-1, %rax
	je fail
    
    push $ident
    push sockfd
    call writeString
    addq $16, %rsp

    #Readline, print it and repeat
    readLoop:
    #Calls readLine(sockfd, &msg)
    push $msg
    push sockfd
    call readLine
    addq $16, %rsp

    movq %rax, %rdx #Count of bytes read is amount we'll now write
    
    checkPing: #Check if it's a ping and respond with a pong, tidy up later
    movl msg, %eax	
    cmpl ping, %eax
    jne checkJoin
    movq $msg, %rdi
    inc %rdi
    movb $'O', (%rdi)
    
    push $msg
    push sockfd
    call writeString
    addq $16, %rsp
    jmp write
    
    checkJoin: #Check if it starts with :PAC and join channel if so, again we'll tidy this up later, just a test
    cmpl join, %eax
    
    jne write
    
    push $joinStr
    push sockfd
    call writeString
    addq $16, %rsp
    
    write:
    #Writes the line we just read
    movq $1, %rax
    movq $1, %rdi
    movq $msg, %rsi
    syscall

    jmp readLoop

fail:
    movq $0, %rdi   #exit(0)
    movq $60, %rax
    syscall
