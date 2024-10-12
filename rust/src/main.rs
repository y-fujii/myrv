#![no_std]
#![no_main]
extern crate alloc;
mod dumb_alloc;
mod entry;
mod uart;
use core::fmt::Write;

const ADDR_HEAP: usize = 0x00004000usize;
const ADDR_UART: *mut u8 = 0x80000000usize as _;

#[global_allocator]
static ALLOC: dumb_alloc::Alloc = dumb_alloc::Alloc::new(ADDR_HEAP);

#[no_mangle]
fn main() -> ! {
    let mut uart = uart::Uart::new(ADDR_UART);
    loop {
        write!(uart, "Hello world!\r\n").unwrap();
    }
}
