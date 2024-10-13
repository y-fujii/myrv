SECTIONS {
	.text    : { *(.text    .text.*   ) }
	.rodata  : { *(.rodata  .rodata.* ) }
	.srodata : { *(.srodata .srodata.*) }
	.sdata   : { *(.sdata   .sdata.*  ) }
	.sbss    : { *(.sbss    .sbss.*   ) }
	.bss     : { *(.bss     .bss.*    ) }
	.data    : { *(.data    .data.*   ) }
	END = .;
}
