; hl - server
; de - path
; bc - port
openPage:
    ld (srv_ptr), hl : ld (path_ptr), de : ld (port_ptr), bc
    xor a : call changeBank


    ex hl, de : ld de, hist : ld bc, 322 : ldir

    ld hl, (srv_ptr) : ld de, (path_ptr) : ld bc, (port_ptr)
    call makeRequest
    xor a : call changeBank

    ld hl, page_buffer : xor a : ld (hl), a :  ld de, page_buffer + 1 : ld bc, #ffff - page_buffer - 1 : ldir

    ld hl, page_buffer : call loadData
    
    xor a : ld (show_offset), a
    inc a : ld (cursor_pos), a
    ret

srv_ptr dw 0
path_ptr dw 0
port_ptr dw 0 

; HL - domain stringZ
; DE - path stringZ
; BC - port stringZ
makeRequest:
    ld (srv_ptr), hl : ld (path_ptr), de : ld (port_ptr), bc

    ld hl, downloading_msg : call showTypePrint
    xor a : call changeBank

; Open TCP connection
    ld hl, cmd_open1 : call uartWriteStringZ
    ld hl, (srv_ptr) : call uartWriteStringZ
    ld hl, cmd_open2 : call uartWriteStringZ
    ld hl, (port_ptr) : call uartWriteStringZ
    ld hl, cmd_open3 : call okErrCmd

    cp 1 : jp nz, reqErr 

; Send request
    ld hl, cmd_send : call uartWriteStringZ
    ld hl, (path_ptr)
    call getStringLength 
    push bc : pop hl : inc hl : inc hl :  call B2D16

    ld hl, B2DBUF : call SkipWhitespace : call uartWriteStringZ  
    ld hl, crlf : call okErrCmd  

    cp 1 : jp nz, reqErr 
wPrmt:
    call uartReadBlocking : call pushRing
    ld hl, send_prompt : call searchRing : cp 1 : jr nz, wPrmt
    
    ld hl, (path_ptr) : call uartWriteStringZ
    
    ld hl, crlf : call uartWriteStringZ : ld a, 1 : ld (connectionOpen), a
    ret

reqErr:  
    ld sp, stack_pointer
    
    ld hl, connectionError : call showTypePrint : call wSec 
    xor a : ld (connectionOpen), a

    call initWifi ; Trying reset ESP and continue work
    jp historyBack ; Let's try back home on one URL :)

; Load data to ram via gopher
; HL - data pointer
; In data_recv downloaded volume
loadData:
    ld (data_pointer), hl, hl, 0, (data_recv), hl
lpLoop:
    call getPacket
    
    ld a, (connectionOpen) : and a : jp z, ldEnd 

    ld de, (data_pointer)
    ld hl, (bytes_avail)
    add hl, de

    ld a, h : cp #40 : jr c, lpLoop 
; a bit buggy 

    ld bc, (bytes_avail) : ld hl, output_buffer : ldir
    ld hl, (data_pointer) : ld de, (bytes_avail) :  add hl, de : ld (data_pointer), hl 
    ld hl, (data_recv) : add hl, de : ld (data_recv), hl

    jp lpLoop

ldEnd 
    ld hl, 0 : ld (data_pointer), hl
    ret

; Download file via gopher
; bc - filename
downloadData:
    ld l, Dos.FA_CREATE_ALWAYS | Dos.FA_WRITE | Dos.FA_READ
    call Dos.fopen

dwnLp:
    call getPacket : ld a, (connectionOpen) : and a : jp z, dwnEnd
    
    
    ld hl, (bytes_avail) : ex hl, de : ld bc, output_buffer 
    call Dos.fwrite

    jp dwnLp
dwnEnd:
    
    call Dos.fclose

    ret

openURI:
    call cleanIBuff 
    
    ld b, 19: ld c, 0 :call gotoXY : ld hl, cleanLine : call printZ64
    ld b, 19: ld c, 0 : call gotoXY : ld hl, hostTxt : call printZ64

    call input

    ld a, (iBuff) : or a : jp z, backToPage

    ld b, 19 : ld c, 0 : call gotoXY : ld hl, cleanLine : call printZ64

    ld hl, iBuff : ld de, d_host : ld bc, 65 : ldir

    ld hl, d_host : ld de, d_path : ld bc, d_port : call openPage
    
    jp showPage
    

data_pointer    defw #4000
data_recv       defw 0
fstream         defb 0 

closed_callback
    xor a
    ld (connectionOpen), a
    ei
    ret

hostTxt   db 'Enter host: ', 0

crlf        defb 13,10, 0

d_path    db '/'
          defs 254
d_host    defs 70
d_port    db '70'
          defs 5

hist            ds 322
connectionOpen  db 0
downloading_msg db 'Downloading...', 0

connectionError db "Issue with making request - trying get back", 0
