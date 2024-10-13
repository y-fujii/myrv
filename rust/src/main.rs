#![no_std]
#![no_main]
extern crate alloc;
mod dumb_alloc;
mod entry;
mod uart;
use core::fmt::Write;

const ADDR_UART: *mut u8 = 0x80000000usize as _;

fn main() {
    let mut uart = uart::Uart::new(ADDR_UART);
    loop {
        write!(uart, "Hello world!\r\n").unwrap();
    }
}
