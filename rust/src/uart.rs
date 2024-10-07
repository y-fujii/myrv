use core::*;

pub struct Uart {
    addr: *mut u8,
}

impl Uart {
    pub fn new(addr: *mut u8) -> Self {
        Uart { addr: addr }
    }

    pub fn write_byte(&mut self, b: u8) {
        unsafe {
            while ptr::read_volatile(self.addr.add(5)) & (1 << 5) == 0 {}
            ptr::write_volatile(self.addr.add(0), b);
        }
    }
}

impl fmt::Write for Uart {
    fn write_str(&mut self, s: &str) -> fmt::Result {
        for b in s.bytes() {
            self.write_byte(b);
        }
        Ok(())
    }
}
