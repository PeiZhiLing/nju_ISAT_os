SECTIONS { 
  . = 0x8000; 
  .text : {*(.text)}   
  . = 0x8130;   
  .data : {*(.data)}   
  . =0x8140;
  .rodata :{*(.rodata)}
}
