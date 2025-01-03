;----------------------------------------------------------------------------
;structure of the device driver request header
;----------------------------------------------------------------------------
REQ_HEAD_PUB    struc
len             db      ?                       ; request length
unit            db      ?                       ; unit number
command         db      ?                       ; command code
status          dw      ?                       ; return status
reserved        db      8 dup (?)
REQ_HEAD_PUB    ends

;----- All requests
REQ_ALL         struc
                db      (16h+4+1) dup (?)       ; max size
REQ_ALL         ends

;----- Request 0: init
REQ_INIT        struc                           
                db      (type REQ_HEAD_PUB) dup (?)
init_num_unit   db      ?                       ; Number of unit
init_free1_ofs  dw      ?                       ; First free byte ofs
init_free1_seg  dw      ?                       ; First free byte seg
init_bpb_ofs    dw      ?                       ; BPB array ofs (cmd line ?)
init_bpb_seg    dw      ?                       ; BPB array seg
init_drv_num    db      ?                       ; driver number (3+)
REQ_INIT        ends    

;----- Request 1: media check
REQ_MEDIA       struc
                db      (type REQ_HEAD_PUB) dup (?)
mdc_media       db      ?                       ; media descriptor
mdc_status      db      ?                       ; status
mdc_pvid_addr   dd      ?                       ; Previous volume ID addr(3+)
REQ_MEDIA       ends

;----- Request 2: build BPB
REQ_BUILD_BPB   struc
                db      (type REQ_HEAD_PUB) dup (?)
bpb_media       db      ?                       ; media descriptor
bpb_trans_ofs   dw      ?                       ; transfer address offset
bpb_trans_seg   dw      ?                       ; transfer address segment
bpb_bpb_ofs     dw      ?
bpb_bpb_seg     dw      ?                       ; BPB address
REQ_BUILD_BPB   ends

;----- Request 4,8,9: I/O
REQ_IO          struc   
                db      (type REQ_HEAD_PUB) dup (?)
io_media        db      ?                       ; media descriptor
io_trans_ofs    dw      ?                       ; transfer address offset
io_trans_seg    dw      ?                       ; transfer address segment
io_sec_cnt      dw      ?                       ; sector count
io_start_sec    dw      ?                       ; starting sector
io_pvid_addr    dd      ?                       ; Previous volume ID addr(3+)
REQ_IO          ends
