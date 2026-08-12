use zeroize::Zeroize;

/// `SecureBuffer` is an in-memory byte buffer that automatically zeroes out
/// its memory contents when dropped, guaranteeing no lingering sensitive document data in RAM.
pub struct SecureBuffer {
    data: Vec<u8>,
}

#[allow(dead_code)]
impl SecureBuffer {
    pub fn new(data: Vec<u8>) -> Self {
        Self { data }
    }

    pub fn as_slice(&self) -> &[u8] {
        &self.data
    }

    pub fn len(&self) -> usize {
        self.data.len()
    }

    pub fn is_empty(&self) -> bool {
        self.data.is_empty()
    }
}

impl Drop for SecureBuffer {
    fn drop(&mut self) {
        // Zeroize memory on drop
        self.data.zeroize();
    }
}

/// `SecureString` is a string buffer that zeroes out its underlying bytes when dropped.
pub struct SecureString {
    data: String,
}

impl SecureString {
    pub fn new(data: String) -> Self {
        Self { data }
    }

    pub fn as_str(&self) -> &str {
        &self.data
    }
}

impl Drop for SecureString {
    fn drop(&mut self) {
        unsafe {
            self.data.as_mut_vec().zeroize();
        }
    }
}
