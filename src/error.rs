//! Simple error handling for fool-proof operation

use std::fmt;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ErrorCode {
    FileExists = 201,
    PermissionDenied = 202,
    InvalidInput = 301,
    SystemError = 500,
}

#[derive(Debug)]
pub struct SimpleError {
    pub code: ErrorCode,
    pub message: String,
}

impl SimpleError {
    pub fn new(code: ErrorCode, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
        }
    }
}

impl fmt::Display for SimpleError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "ERR-{}: {}", self.code as u32, self.message)
    }
}

impl std::error::Error for SimpleError {}

impl From<std::io::Error> for SimpleError {
    fn from(err: std::io::Error) -> Self {
        SimpleError::new(ErrorCode::SystemError, format!("I/O error: {}", err))
    }
}

impl From<csv::Error> for SimpleError {
    fn from(err: csv::Error) -> Self {
        SimpleError::new(ErrorCode::SystemError, format!("CSV error: {}", err))
    }
}

pub type Result<T> = std::result::Result<T, SimpleError>;
