%include "asm_io.inc"
%include "io.inc"
segment .data
    score dd 0
    exitFormat db "Congratulations! Score: %d",0xA,0
    lossFormat db "You lost:-(",0xA,0
    score_string db "SCORE: ",0
    clear db 27,"[2J",27,"[1;1H",0
    scanFormat db "%c",0
    file db "input.txt",0
    mode db "r",0
    formatA db "%c",0
    x dd 3
    y dd 3
    prevX dd 0
    prevY dd 0
    rows dd 8
    cols dd 27

segment .bss
    text resb 2000

segment .text
    global  asm_main
        extern printf
        extern fscanf
	extern fopen
	extern fclose
	extern scanf
	extern getchar
	extern putchar
asm_main:
    enter   0,0               ; setup routine
    pusha
    ;***************CODE STARTS HERE*******
	mov eax, clear    ; two lines to clear
	call print_string ; clear the screen
	mov eax, score_string
        call print_string
        mov eax, [score]
        call print_int
        call print_nl
        call load	  ; load the file into text
	call update       ; update the file with the location 
        mov eax, text
	call print_string

	mov ecx, 55 
top:
	call movement
	call update
	mov eax, clear    ; two lines to clear
        call print_string ; clear the screen
        mov eax, score_string   ; moves "SCORE: " into eax
        call print_string       ; prints "SCORE: "
        mov eax, [score]        ; sets up actual score
        call print_int          ; prints actual score
        call print_nl
	mov eax, text
	call print_string
	loop top
        
        ;printf("You lost:-(")
        push lossFormat
        call printf
        add esp, 0x4
        jmp loss_finish

; an E was encountered break out of loop and exit
exit_game:
        ; printf("Congratulations! Score: %d", &score)
        push dword [score]
        push exitFormat
        call printf
        add esp, 8h

loss_finish:
    ;***************CODE ENDS HERE*********
    popa
    mov     eax, 0            ; return back to C
    leave                     
    ret

;*********************************
;* Function to load var text with*
;* input from input.txt          * 
;*********************************
load:
	push eax
	push esi

	sub esp, 20h                ; add local variables i.e. grow stack

	;get the file pointer
	mov dword [esp+4], mode     ; the mode for the file which is "r"	
	mov dword [esp], file       ; the name of the file.  Hard coded here (input.txt)
	call fopen                  ; call fopen to open the file

	;read stuff
	mov [esp], eax              ; mov the file pointer to param 1
	mov eax, esp                ; use stack to store a pointer where char goes
	add eax, 1Ch                ; address is 1C up from the bottom of the stack
	mov [esp+8], eax            ; pointer is param 3
	mov dword [esp+4], scanFormat   ;format is param 2

	mov edx, 0
	mov [prevX], edx
  	mov [prevY], edx

scan:	
        call fscanf         ; call scanf 
	cmp eax, 0          ; eax will be less than 1 when EOF
	jl done             ; eof means quit
	mov eax, [esp+1Ch]  ; mov the result (on the stack) to eax
	
	cmp al, 'M'
	jz Mario
	
	mov edx, [prevX]    ; increment prevX
	inc edx
	mov [prevX], edx

	cmp al, 10
	jz NewLine
	
	jmp save

NewLine:
	mov dword [prevX], 0
	mov edx, [prevY]
	inc edx
	mov [prevY], edx
	jmp save
	
Mario:
	mov edx, [prevX]
	mov [x], edx
	mov edx, [prevY]
	mov [y], edx
	jmp save
	
save:
	mov [text + esi], al    ; store in the array
	inc esi                 ; add one to esi (index in the array)
	cmp esi, 2000           ; dont go tooo far into the array
	jz done                 ; quit if went too far
	jmp scan                ; loop back

done:
	call fclose             ; close the file pointer
	mov byte [text+esi], 0  ; set the last char to null
	add esp, 20h            ; unallocate stack space
	
	pop esi	                ; restore registers
	pop eax
	ret

;*********************************
;* Function to update the screen *
;*                               * 
;*********************************
update:
	push eax
	push ebx 
        push ecx

	;update the new loc
	mov eax, [x]
	mov ebx, [y]
	mov edx, 0
	imul ebx, [cols]
        add eax, ebx

        ; determine if next position is an asterisk
        mov cl, '*'
        cmp cl, [text + eax]
        je wall
        
        ; determine if next position is a block
        mov cl, 'B'
        cmp cl, [text + eax]
        je wall

        ; determine if next position is gold
        mov cl, 'G'
        cmp cl, [text + eax]
        je gold

        ; determine if next position is exit
        mov cl, 'E'
        cmp cl, [text + eax]
        je setup_exit

        ; The next position is not a block, asterisk, or E
        ; Mario's position is updated to next position
	mov byte [text + eax], 'M'
        jmp update_old_location

; will return M to previous position
wall:
        mov eax, [prevX]
        mov ebx, [prevY]
        mov [x], eax
        mov [y], ebx
        jmp update_done

gold:
        mov eax, [score]
        add eax, 5
        mov [score], eax

update_old_location:
        ;update the old loc
	mov eax, [prevX]
	mov ebx, [prevY]
	mov edx, 0
	imul ebx, [cols]

	add eax, ebx
	mov byte [text + eax], ' '

update_done:
        pop ecx
        pop ebx
        pop eax
        ret

setup_exit:
        mov byte [text + eax], 'M'
        ;update the old loc
	mov eax, [prevX]
	mov ebx, [prevY]
	mov edx, 0
	imul ebx, [cols]

	add eax, ebx
	mov byte [text + eax], ' '
        mov eax, clear
        call print_string
        mov eax, text
        call print_string
        pop ecx
        pop ebx
        pop eax
        add esp, 0x4
        jmp exit_game

;*********************************
;* Function to get mouse movement*
;*                               * 
;*********************************
movement:	
    pushad
    mov ebx, [x]
    mov [prevX], ebx    ; save old value of x in prevX
    mov ebx, [y]
    mov [prevY], ebx    ; save old value of y in prevY
    call canonical_off
    call echo_off
    mov eax, formatA
    push eax
    call getchar
    call getchar
    call getchar        ; actual arrow char code
    call canonical_on
    call echo_on
    cmp eax, 43h        ; right
    jz right
    cmp eax, 44h        ; left
    jz left
    cmp eax, 42h        ; up
    jz up
    cmp eax, 41h        ; down
    jz down
    jmp over

right:
    mov eax, [x]
    inc eax
    mov [x], eax
    jmp mDone

left:
    mov eax, [x]
    dec eax
    mov [x], eax
    jmp mDone

up:
    mov eax, [y]
    add eax, 1
    mov [y], eax
    jmp mDone

down:
    mov eax, [y]
    sub eax, 1
    mov [y], eax
    jmp mDone

mDone:
over:
    pop eax
    popad
    ret
