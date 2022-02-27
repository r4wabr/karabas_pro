MODULE SAVELIJ  ;25190
  PUBLIC disk_initialize
  PUBLIC _disk_read
  PUBLIC _disk_write
  PUBLIC disk_status 
  
	RSEG CODE
	
disk_status:
	ld a,0xff
ds_m=$-1
	ret
	        
	
get_params
	push ix
	ld ix,6
	add ix,sp
	ld a,(ix+0)
	ex af,af
	ld a,(ix+4)
	ld h,(ix+3)
	ld l,(ix+2)
	pop ix
	ret
	
;������� SD �����
;LAST UPDATE 14.04.2009 savelij
;������� ��������� �����:
;HL-����� �������� � ������
;BCDE-32-� ������ ����� �������
;A-���������� ������ (����=512 ����) - ������ ��� ������������ ������/������
;������ ���������� �� ������:
;A=0 - ������������� ������ �������
;A=1 - ����� �� ������� ��� �� ��������
;A=2 - ����� �������� �� ������
;A=3 - ������� ������ � ������ 0 �����
P_DATA    EQU 0x0057    ;���� ������
;P_CONF    EQU 0x8057    ;���� ������������
P_CONF    EQU 0x0077    ;���� ������������
CMD_12    EQU 0x4C    ;STOP_TRANSMISSION
CMD_17    EQU 0x51    ;READ_SINGLE_BLOCK
CMD_18    EQU 0x52    ;READ_MULTIPLE_BLOCK
CMD_24    EQU 0x58    ;WRITE_BLOCK
CMD_25    EQU 0x59    ;WRITE_MULTIPLE_BLOCK
CMD_55    EQU 0x77    ;APP_CMD
CMD_58    EQU 0x7A    ;READ_OCR
CMD_59    EQU 0x7B    ;CRC_ON_OFF
ACMD_41   EQU 0x69   ;SD_SEND_OP_COND


disk_initialize:
    ld a,(ds_m)
    or a
    ret z
    CALL CS_HIGH    ;�������� ������� ����� ��� ������ ������
    LD BC,P_DATA
    LD DE,0x20FF    ;��� ������ ����� � <1>
SD_INITloop
    OUT (C),E    ;���������� � ���� ����� ��������
    DEC D    ;���������� �������� ��������� ������
    JR NZ,SD_INITloop    ;��� ����
    XOR A    ;��������� ������� �� 256
    EX AF,AF    ;��� �������� ������������� �����
ZAW001    
    LD HL,CMD00    ;���� ������� ������
    CALL OUTCOM    ;���� �������� �������� ����������� � ����� SPI
    CALL IN_OOUT    ;������ ����� �����
    EX AF,AF
    DEC A
    JP Z,ZAW003    ;���� ����� 256 ��� �� ��������, �� ����� ���
    EX AF,AF
    DEC A
    JR NZ,ZAW001    ;����� ����� <1>, ������� � SPI ������ �������
    LD HL,CMD08    ;������ �� �������������� ����������
    CALL OUTCOM    ;������� �������������� ������� �� ������������
    CALL IN_OOUT    ;������ 2.0 � ������ SDHC, ���� � ����� SD �������
    IN H,(C)    ;� A=��� ������ �����
    NOP    ;��������� 4 ����� �������� ������
    IN H,(C)    ;�� �� ����������
    NOP
    IN H,(C)
    NOP
    IN H,(C)
    LD HL,0    ;HL=�������� ��� ������� �������������
    BIT 2,A    ;���� ��� 2 ����������, �� ����� �����������
    JR NZ,ZAW006    ;����������� ����� ������ <������ �������>
    LD H,0x40    ;���� ������ �� ����, �� ����� SDHC, ���� ��� ����� SD
ZAW006    
    LD A,CMD_55    ;��������� ������� ���������� �������������
    CALL OUT_COM    ;��� ���� MMC ����� ������ ���� ������ �������
    CALL IN_OOUT    ;�������������� ������� � ����� MMC-�����
    in (c)
    in (c)
	LD A,ACMD_41    ;������� ��������� ��������, �� ����������
    OUT (C),A    ;����� ������� ������� ������������� � ���������
    NOP    ;��� 6 ���������� ��� ������������� SDHC �����
    OUT (C),H    ;��� ����������� �������
    NOP
    OUT (C),L
    NOP
    OUT (C),L
    NOP
    OUT (C),L
    LD A,0xFF
    OUT (C),A
    CALL IN_OOUT    ;���� �������� ����� � ����� ����������
    AND A    ;����� �������� �������� 1 �������
    JR NZ,ZAW006
ZAW004    LD A,CMD_59    ;������������� ��������� CRC16
    CALL OUT_COM
    CALL IN_OOUT
    AND A
    JR NZ,ZAW004
ZAW005    LD HL,CMD16    ;������������� ������ ������ ����� 512 ����
    CALL OUTCOM
    CALL IN_OOUT
    AND A
    JR NZ,ZAW005
	
;�������� ������ �����
	ld a,CMD_58 ;READ_OCR
	ld bc,P_DATA
    CALL OUT_COM
    CALL IN_OOUT
	in a,(C)
	nop
	in h,(C) 
	nop
	in h,(C) 
	nop
	in h,(C)
	and 0x40
	ld (zsd_blsize),a
;��������� ������� ����� ��� ������ ������� ������ �����
CS_HIGH    
    PUSH AF
    ld bc,P_CONF
    LD A,3
    OUT (c),A    ;�������� �������, ������� ����� �����
    XOR A
    ld bc,P_DATA
    OUT (c),A    ;�������� ���� ������
    POP AF    ;��������� ����� ����� �� ������, ������ ���������
    ld a,0
	ld (ds_m),a
    RET    ;���������� ��� ������ 1, � ��� ������ ����� �����
        ;������ ����� ���������� �������� �� ����� �������
        ;����� � ��������� �� ������� ��������������
;������� ��� �� ������ ����� � ����� ������ 1
ZAW003    
    CALL zsd_off
    ld a,3
    RET
zsd_off    ;patch
	ld bc,P_CONF
    XOR A
    OUT (c),A    ;���������� ������� �����
	dec b		;P_DATA
    OUT (c),A    ;��������� ����� ������
    RET
;�������� ����� �������� 0
CS__LOW    ;patch
    PUSH AF
	ld bc,P_CONF
    LD A,1
    OUT (c),A
    POP AF
    RET
;������ � ����� ������� � ������������ ���������� �� ������
;����� ������� � <HL>
OUTCOM    ;patch
    CALL CS__LOW
    LD BC,0x600+P_DATA
    OTIR    ;�������� 6 ���� ������� �� ������
    RET
;������ � ����� ������� � �������� �����������
;�-��� �������, �������� ������� ����� 0
OUT_COM    ;patch
    CALL CS__LOW
    LD BC,P_DATA
    in (c)
    in (c)
    OUT (C),A
    XOR A
    OUT (C),A
    NOP
    OUT (C),A
    NOP
    OUT (C),A
    NOP
    OUT (C),A
    DEC A
    OUT (C),A    ;����� ������ CRC7 � �������� ���
    RET
;������ ������� ������/������ � ������� ������� � BCDE ��� ���� ������������ �������
;��� ���������� ������� ������� ����� ������� ����� �������� �� ��� ������, ��� ���� 
;SDHC, ���� � ����� ������ ������� �� ������� ���������
SECM200    PUSH HL  ;patch
    PUSH AF
	ld h,b
	ld l,c
	call CS__LOW
    LD BC,P_DATA
	ld a,0x00
zsd_blsize=$-1
	or a        
    JR NZ,SECN200    ;�� ���������
    EX DE,HL    ;��� ���������� ���� ��������������
    ADD HL,HL    ;�������� ����� ������� �� 512 (0x200)
    EX DE,HL
    ADC HL,HL
    LD H,L
    LD L,D
    LD D,E
    LD E,0
SECN200    
    POP AF    ;������������� ����� ������� ��������� � <HLDE>
    in (c)
    in (c)
    OUT (C),A    ;����� ������� �� <�> �� SD �����
    NOP    ;���������� 4 ����� ���������
    OUT (C),H    ;����� ����� ������� �� ��������
    NOP
    OUT (C),L
    NOP
    OUT (C),D
    NOP
    OUT (C),E    ;�� �������� �����
    LD A,0xFF
    OUT (C),A    ;����� ������ CRC7 � �������� ���
    POP HL
    RET
;������ ������ ����� �� 32 ���, ���� ����� �� 0xFF - ����������� �����
IN_OOUT    ;patch
    push de
    LD DE,0x20FF
	ld bc,P_DATA
IN_WAIT    IN A,(c)
    CP E
    JR NZ,IN_EXIT
IN_NEXT    DEC D
    JR NZ,IN_WAIT
IN_EXIT    POP DE
    RET
CMD00    DEFB  0x40,0x00,0x00,0x00,0x00,0x95 ;GO_IDLE_STATE
    ;������� ������ � �������� ����� � SPI ����� ����� ��������� �������
CMD08    DEFB  0x48,0x00,0x00,0x01,0xAA,0x87 ;SEND_IF_COND
    ;������ �������������� ����������
CMD16    DEFB 0x50,0x00,0x00,0x02,0x00,0xFF ;SET_BLOCKEN
    ;������� ��������� ������� 
;�������������� ������

_disk_read:
    call get_params 
    LD A,CMD_18
    CALL SECM200    ;���� ������� ��������������� ������
    EX AF,AF
RDMULT1    EX AF,AF
RDMULT2
    CALL IN_OOUT
    CP 0xFE
    JR NZ,RDMULT2    ;���� ������ ���������� 0xFE ��� ������ ������
    LD BC,P_DATA
    INIR
    nop
    INIR
	nop
    IN A,(C)
    NOP
    IN A,(C)
    EX AF,AF
    DEC A
    JR NZ,RDMULT1    ;���������� ���� �� ��������� �������
    LD A,CMD_12    ;�� ��������� ������ ���� ������� ����� <����>
    CALL OUT_COM    ;������� ������������ �� ����� �������� �
RDMULT3
    CALL IN_OOUT    ;������ ��������������� ����� �������� 12
    INC A
    JR NZ,RDMULT3    ;���� ������������ �����
    JP CS_HIGH    ;������� ����� � ����� � ������� � ����� 0

;�������������� ������

_disk_write:
    call get_params 
    LD A,CMD_25 ;���� ������� ��������������� ������
    CALL SECM200
WRMULTI2
    CALL IN_OOUT
    INC A
    JR NZ,WRMULTI2 ;���� ������������ �����
    EX AF,AF
WRMULT1 EX AF,AF
    LD A,0xFC ;����� ��������� ������, ��� ���� � ������ CRC16
    LD BC,P_DATA
    OUT (C),A
    LD B,0x80
    OTIR
    LD B,0x80
    OTIR
    LD B,0x80
    OTIR
    LD B,0x80
    OTIR
    LD A,0xFF
    OUT (C),A
    NOP
    OUT (C),A
WRMULTI3
    CALL IN_OOUT
    INC A
    JR NZ,WRMULTI3 ;���� ������������ �����
    EX AF,AF
    DEC A
    JR NZ,WRMULT1 ;���������� ���� ������� �� ���������
    LD C,P_DATA
    LD A,0xFD
    OUT (C),A ;���� ������� ��������� ������
WRMULTI4
    CALL IN_OOUT
    INC A
    JR NZ,WRMULTI4 ;���� ������������ �����
    JP CS_HIGH ;������� ����� ����� � ������� � ����� 0

END


