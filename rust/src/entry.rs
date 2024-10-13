use crate::dumb_alloc;
use core::*;

#[global_allocator]
static mut ALLOC: dumb_alloc::Alloc = dumb_alloc::Alloc::new(ptr::null_mut());

extern "C" {
    static mut END: [u8; 0];
}

#[panic_handler]
fn panic(_: &panic::PanicInfo) -> ! {
    loop {}
}

#[no_mangle]
fn _start_rust() -> ! {
    // TODO: initialize data, bss.
    unsafe {
        ALLOC = dumb_alloc::Alloc::new(END.as_mut_ptr());
    }
    crate::main();
    loop {}
}

#[rustfmt::skip]
arch::global_asm!(r#"
.global _start
_start:
    li sp, 0
    j _start_rust
"#);
