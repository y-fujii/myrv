#![no_std]
#![no_main]
use core::*;

arch::global_asm!(r#"
.global _start
_start:
	li sp, 0
	j main
"#);

#[panic_handler]
fn panic(_: &panic::PanicInfo) -> ! {
    loop {}
}

#[no_mangle]
fn main() -> ! {
    loop {}
}
