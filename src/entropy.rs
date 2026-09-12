//! Deep Entropy engine - military-grade randomness

use sha2::{Sha512, Digest};
use rand::Rng;
use getrandom::getrandom;
use crate::error::{SimpleError, ErrorCode, Result};

pub struct DeepEntropy {
    iterations: u32,
}

impl DeepEntropy {
    pub fn new(iterations: u32) -> Self {
        Self { iterations }
    }
    
    fn get_seed(&self) -> Result<[u8; 64]> {
        let mut seed = [0u8; 64];
        if let Err(e) = getrandom(&mut seed) {
            return Err(SimpleError::new(ErrorCode::SystemError, format!("getrandom failed: {}", e)));
        }
        Ok(seed)
    }
    
    pub fn generate_password(&self, length: usize, charset: &str) -> Result<String> {
        if charset.is_empty() {
            return Err(SimpleError::new(ErrorCode::InvalidInput, "Empty charset"));
        }
        
        let mut seed = self.get_seed()?;
        
        for i in 0..self.iterations {
            let mut hasher = Sha512::new();
            hasher.update(&seed);
            hasher.update(&i.to_le_bytes());
            let result = hasher.finalize();
            seed[..64].copy_from_slice(&result[..64]);
        }
        
        let charset_chars: Vec<char> = charset.chars().collect();
        let charset_len = charset_chars.len();
        let mut password = String::with_capacity(length);
        
        for i in 0..length {
            let byte_index = (i * 2) % 64;
            let byte1 = seed[byte_index];
            let byte2 = seed[(byte_index + 1) % 64];
            let value = ((byte1 as u32) << 8) | (byte2 as u32);
            let char_index = (value as usize) % charset_len;
            password.push(charset_chars[char_index]);
        }
        
        Ok(password)
    }
    
    pub fn generate_password_standard(&self, length: usize, charset: &str) -> Result<String> {
        if charset.is_empty() {
            return Err(SimpleError::new(ErrorCode::InvalidInput, "Empty charset"));
        }
        
        let charset_chars: Vec<char> = charset.chars().collect();
        let charset_len = charset_chars.len();
        let mut rng = rand::thread_rng();
        let mut password = String::with_capacity(length);
        
        for _ in 0..length {
            let index = rng.gen_range(0..charset_len);
            password.push(charset_chars[index]);
        }
        
        Ok(password)
    }
}
