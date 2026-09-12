#!/bin/bash
# ==============================================================================
# Script Name : build_project.sh
# Version     : 1.0.0
# Date        : 2026-09-03
# Description : Fool-proof Rust project builder - regenerates all source files
# Safety      : Creates backup of old src/ directory before overwriting
# ==============================================================================

set -e

PROJECT_DIR="$HOME/secure-passgen"
SRC_DIR="$PROJECT_DIR/src"
BACKUP_DIR="$PROJECT_DIR/src_backup_$(date +%Y%m%d_%H%M%S)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

print_banner() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}Secure PassGen - Automatic Source Code Generator${NC}             ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

check_prerequisites() {
    echo -e "${BOLD}[1/7] Checking prerequisites...${NC}"
    
    if ! command -v cargo &> /dev/null; then
        echo -e "${RED}ERROR: cargo not found. Install Rust from https://rustup.rs/${NC}"
        exit 1
    fi
    
    if [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${RED}ERROR: Project directory not found: $PROJECT_DIR${NC}"
        exit 1
    fi
    
    echo -e "  ${GREEN}✓${NC} Cargo: $(cargo --version)"
    echo -e "  ${GREEN}✓${NC} Project directory: $PROJECT_DIR"
}

backup_old_source() {
    echo -e "${BOLD}[2/7] Backing up old source files...${NC}"
    
    if [ -d "$SRC_DIR" ]; then
        cp -r "$SRC_DIR" "$BACKUP_DIR"
        echo -e "  ${GREEN}✓${NC} Backup created: $BACKUP_DIR"
    else
        echo -e "  ${YELLOW}⚠${NC} No existing src/ directory found"
    fi
}

create_directory_structure() {
    echo -e "${BOLD}[3/7] Creating directory structure...${NC}"
    
    rm -rf "$SRC_DIR"
    mkdir -p "$SRC_DIR/plugins"
    mkdir -p "$SRC_DIR/i18n"
    
    echo -e "  ${GREEN}✓${NC} Created: $SRC_DIR"
    echo -e "  ${GREEN}✓${NC} Created: $SRC_DIR/plugins"
    echo -e "  ${GREEN}✓${NC} Created: $SRC_DIR/i18n"
}

generate_cargo_toml() {
    echo -e "${BOLD}[4/7] Generating Cargo.toml...${NC}"
    
    cat > "$PROJECT_DIR/Cargo.toml" << 'CARGO_EOF'
[package]
name = "secure-passgen"
version = "3.0.0"
edition = "2021"
authors = ["Boldwelder & Adjutans-1"]
description = "Military-grade fool-proof password generator with i18n and Unicode support"
license = "MIT"

[dependencies]
clap = { version = "4.4", features = ["derive"] }
dialoguer = "0.11"
rand = "0.8"
getrandom = { version = "0.2", features = ["std"] }
sha2 = "0.10"
colored = "2.1"
csv = "1.3"
chrono = "0.4"
sys-info = "0.9"
hostname = "0.3"

[dev-dependencies]
tempfile = "3.8"

[profile.release]
opt-level = 3
lto = true
codegen-units = 1

[[bin]]
name = "secure-passgen"
path = "src/main.rs"
CARGO_EOF

    echo -e "  ${GREEN}✓${NC} Cargo.toml written"
}

generate_source_files() {
    echo -e "${BOLD}[5/7] Generating Rust source files (this may take a moment)...${NC}"
    
    # ---------- lib.rs ----------
    cat > "$SRC_DIR/lib.rs" << 'LIB_EOF'
//! Secure PassGen Library - Modular exports

pub mod cli;
pub mod config;
pub mod csv_writer;
pub mod entropy;
pub mod error;
pub mod interactive;
pub mod plugins;
pub mod i18n;
pub mod charsets;
pub mod auto_recovery;
LIB_EOF
    echo -e "  ${GREEN}✓${NC} lib.rs"
    
    # ---------- error.rs ----------
    cat > "$SRC_DIR/error.rs" << 'ERROR_EOF'
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
ERROR_EOF
    echo -e "  ${GREEN}✓${NC} error.rs"
    
    # ---------- i18n.rs ----------
    cat > "$SRC_DIR/i18n.rs" << 'I18N_EOF'
//! Internationalization - 20 language support

use std::collections::HashMap;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Language {
    English, Hungarian, Spanish, Chinese, Hindi, Arabic, Bengali, Portuguese,
    Russian, Japanese, German, French, Korean, Turkish, Vietnamese,
    Italian, Polish, Ukrainian, Dutch, Romanian,
}

impl Language {
    pub fn code(&self) -> &'static str {
        match self {
            Language::English => "en", Language::Hungarian => "hu",
            Language::Spanish => "es", Language::Chinese => "zh",
            Language::Hindi => "hi", Language::Arabic => "ar",
            Language::Bengali => "bn", Language::Portuguese => "pt",
            Language::Russian => "ru", Language::Japanese => "ja",
            Language::German => "de", Language::French => "fr",
            Language::Korean => "ko", Language::Turkish => "tr",
            Language::Vietnamese => "vi", Language::Italian => "it",
            Language::Polish => "pl", Language::Ukrainian => "uk",
            Language::Dutch => "nl", Language::Romanian => "ro",
        }
    }
    
    pub fn name(&self) -> &'static str {
        match self {
            Language::English => "English", Language::Hungarian => "Magyar",
            Language::Spanish => "Español", Language::Chinese => "中文",
            Language::Hindi => "हिन्दी", Language::Arabic => "العربية",
            Language::Bengali => "বাংলা", Language::Portuguese => "Português",
            Language::Russian => "Русский", Language::Japanese => "日本語",
            Language::German => "Deutsch", Language::French => "Français",
            Language::Korean => "한국어", Language::Turkish => "Türkçe",
            Language::Vietnamese => "Tiếng Việt", Language::Italian => "Italiano",
            Language::Polish => "Polski", Language::Ukrainian => "Українська",
            Language::Dutch => "Nederlands", Language::Romanian => "Română",
        }
    }
    
    pub fn from_code(code: &str) -> Option<Language> {
        match code.to_lowercase().as_str() {
            "en" | "english" => Some(Language::English),
            "hu" | "hungarian" | "magyar" => Some(Language::Hungarian),
            "es" | "spanish" => Some(Language::Spanish),
            "zh" | "chinese" => Some(Language::Chinese),
            "hi" | "hindi" => Some(Language::Hindi),
            "ar" | "arabic" => Some(Language::Arabic),
            "bn" | "bengali" => Some(Language::Bengali),
            "pt" | "portuguese" => Some(Language::Portuguese),
            "ru" | "russian" => Some(Language::Russian),
            "ja" | "japanese" => Some(Language::Japanese),
            "de" | "german" => Some(Language::German),
            "fr" | "french" => Some(Language::French),
            "ko" | "korean" => Some(Language::Korean),
            "tr" | "turkish" => Some(Language::Turkish),
            "vi" | "vietnamese" => Some(Language::Vietnamese),
            "it" | "italian" => Some(Language::Italian),
            "pl" | "polish" => Some(Language::Polish),
            "uk" | "ukrainian" => Some(Language::Ukrainian),
            "nl" | "dutch" => Some(Language::Dutch),
            "ro" | "romanian" => Some(Language::Romanian),
            _ => None,
        }
    }
    
    pub fn detect_system_language() -> Language {
        let lang_env = std::env::var("LANG")
            .or_else(|_| std::env::var("LANGUAGE"))
            .unwrap_or_else(|_| "en_US.UTF-8".to_string())
            .to_lowercase();
        
        if lang_env.starts_with("hu") { Language::Hungarian }
        else if lang_env.starts_with("es") { Language::Spanish }
        else if lang_env.starts_with("zh") { Language::Chinese }
        else if lang_env.starts_with("hi") { Language::Hindi }
        else if lang_env.starts_with("ar") { Language::Arabic }
        else if lang_env.starts_with("bn") { Language::Bengali }
        else if lang_env.starts_with("pt") { Language::Portuguese }
        else if lang_env.starts_with("ru") { Language::Russian }
        else if lang_env.starts_with("ja") { Language::Japanese }
        else if lang_env.starts_with("de") { Language::German }
        else if lang_env.starts_with("fr") { Language::French }
        else if lang_env.starts_with("ko") { Language::Korean }
        else if lang_env.starts_with("tr") { Language::Turkish }
        else if lang_env.starts_with("vi") { Language::Vietnamese }
        else if lang_env.starts_with("it") { Language::Italian }
        else if lang_env.starts_with("pl") { Language::Polish }
        else if lang_env.starts_with("uk") { Language::Ukrainian }
        else if lang_env.starts_with("nl") { Language::Dutch }
        else if lang_env.starts_with("ro") { Language::Romanian }
        else { Language::English }
    }
}

pub struct Translations {
    language: Language,
    strings: HashMap<&'static str, &'static str>,
}

impl Translations {
    pub fn new(language: Language) -> Self {
        let strings = Self::load_strings(language);
        Self { language, strings }
    }
    
    pub fn language(&self) -> Language {
        self.language
    }
    
    pub fn get(&self, key: &'static str) -> &'static str {
        self.strings.get(key).unwrap_or(&key)
    }
    
    fn load_strings(language: Language) -> HashMap<&'static str, &'static str> {
        let mut map = HashMap::new();
        
        map.insert("welcome", "Secure PassGen - Military-Grade Password Generator");
        map.insert("generating", "Generating passwords...");
        map.insert("completed", "Operation completed successfully");
        map.insert("success", "SUCCESS");
        map.insert("file_saved", "File saved to");
        map.insert("auto_fixes", "Automatic Fixes Applied");
        
        match language {
            Language::Hungarian => {
                map.insert("welcome", "Secure PassGen - Katonai Szintű Jelszógenerátor");
                map.insert("generating", "Jelszavak generálása...");
                map.insert("completed", "A művelet sikeresen befejeződött");
                map.insert("success", "SIKER");
                map.insert("file_saved", "Fájl mentve:");
                map.insert("auto_fixes", "Automatikus Javítások");
            }
            Language::Spanish => {
                map.insert("welcome", "Secure PassGen - Generador de Contraseñas");
                map.insert("generating", "Generando contraseñas...");
                map.insert("completed", "Operación completada con éxito");
                map.insert("success", "ÉXITO");
                map.insert("file_saved", "Archivo guardado en");
                map.insert("auto_fixes", "Correcciones Automáticas");
            }
            Language::Chinese => {
                map.insert("welcome", "Secure PassGen - 军事级密码生成器");
                map.insert("generating", "正在生成密码...");
                map.insert("completed", "操作成功完成");
                map.insert("success", "成功");
                map.insert("file_saved", "文件已保存到");
                map.insert("auto_fixes", "已应用自动修复");
            }
            Language::German => {
                map.insert("welcome", "Secure PassGen - Passwortgenerator");
                map.insert("generating", "Passwörter werden generiert...");
                map.insert("completed", "Vorgang erfolgreich abgeschlossen");
                map.insert("success", "ERFOLG");
                map.insert("file_saved", "Datei gespeichert in");
                map.insert("auto_fixes", "Automatische Korrekturen");
            }
            Language::French => {
                map.insert("welcome", "Secure PassGen - Générateur de Mots de Passe");
                map.insert("generating", "Génération des mots de passe...");
                map.insert("completed", "Opération terminée avec succès");
                map.insert("success", "SUCCÈS");
                map.insert("file_saved", "Fichier enregistré dans");
                map.insert("auto_fixes", "Corrections Automatiques");
            }
            Language::Russian => {
                map.insert("welcome", "Secure PassGen - Генератор Паролей");
                map.insert("generating", "Генерация паролей...");
                map.insert("completed", "Операция успешно завершена");
                map.insert("success", "УСПЕХ");
                map.insert("file_saved", "Файл сохранен в");
                map.insert("auto_fixes", "Автоматические Исправления");
            }
            Language::Japanese => {
                map.insert("welcome", "Secure PassGen - パスワードジェネレーター");
                map.insert("generating", "パスワードを生成中...");
                map.insert("completed", "操作が正常に完了しました");
                map.insert("success", "成功");
                map.insert("file_saved", "ファイルが保存されました:");
                map.insert("auto_fixes", "自動修正");
            }
            Language::Arabic => {
                map.insert("welcome", "Secure PassGen - مولد كلمات المرور");
                map.insert("generating", "جاري إنشاء كلمات المرور...");
                map.insert("completed", "تمت العملية بنجاح");
                map.insert("success", "نجاح");
                map.insert("file_saved", "تم حفظ الملف في");
                map.insert("auto_fixes", "الإصلاحات التلقائية");
            }
            _ => {}
        }
        
        map
    }
}
I18N_EOF
    echo -e "  ${GREEN}✓${NC} i18n.rs"
    
    # ---------- charsets.rs ----------
    cat > "$SRC_DIR/charsets.rs" << 'CHAR_EOF'
//! Unicode character sets for 20+ languages

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum CharsetLanguage {
    Latin, Hungarian, Chinese, Japanese, Korean, Arabic, Hebrew, Hindi,
    Bengali, Thai, Greek, Cyrillic, Armenian, Georgian, Tamil, Telugu,
    Kannada, Malayalam, Gurmukhi, Sinhala,
}

impl CharsetLanguage {
    pub fn name(&self) -> &'static str {
        match self {
            CharsetLanguage::Latin => "Latin (Default)",
            CharsetLanguage::Hungarian => "Magyar (Hungarian)",
            CharsetLanguage::Chinese => "中文 (Chinese)",
            CharsetLanguage::Japanese => "日本語 (Japanese)",
            CharsetLanguage::Korean => "한국어 (Korean)",
            CharsetLanguage::Arabic => "العربية (Arabic)",
            CharsetLanguage::Hebrew => "עברית (Hebrew)",
            CharsetLanguage::Hindi => "हिन्दी (Hindi)",
            CharsetLanguage::Bengali => "বাংলা (Bengali)",
            CharsetLanguage::Thai => "ไทย (Thai)",
            CharsetLanguage::Greek => "Ελληνικά (Greek)",
            CharsetLanguage::Cyrillic => "Кириллица (Cyrillic)",
            CharsetLanguage::Armenian => "Հայերեն (Armenian)",
            CharsetLanguage::Georgian => "ქართული (Georgian)",
            CharsetLanguage::Tamil => "தமிழ் (Tamil)",
            CharsetLanguage::Telugu => "తెలుగు (Telugu)",
            CharsetLanguage::Kannada => "ಕನ್ನಡ (Kannada)",
            CharsetLanguage::Malayalam => "മലയാളം (Malayalam)",
            CharsetLanguage::Gurmukhi => "ਪੰਜਾਬੀ (Gurmukhi)",
            CharsetLanguage::Sinhala => "සිංහල (Sinhala)",
        }
    }
    
    pub fn from_code(code: &str) -> Option<CharsetLanguage> {
        match code.to_lowercase().as_str() {
            "latin" | "en" | "english" | "default" => Some(CharsetLanguage::Latin),
            "hu" | "hungarian" | "magyar" => Some(CharsetLanguage::Hungarian),
            "zh" | "chinese" => Some(CharsetLanguage::Chinese),
            "ja" | "japanese" => Some(CharsetLanguage::Japanese),
            "ko" | "korean" => Some(CharsetLanguage::Korean),
            "ar" | "arabic" => Some(CharsetLanguage::Arabic),
            "he" | "hebrew" => Some(CharsetLanguage::Hebrew),
            "hi" | "hindi" => Some(CharsetLanguage::Hindi),
            "bn" | "bengali" => Some(CharsetLanguage::Bengali),
            "th" | "thai" => Some(CharsetLanguage::Thai),
            "el" | "greek" => Some(CharsetLanguage::Greek),
            "ru" | "russian" | "cyrillic" => Some(CharsetLanguage::Cyrillic),
            "hy" | "armenian" => Some(CharsetLanguage::Armenian),
            "ka" | "georgian" => Some(CharsetLanguage::Georgian),
            "ta" | "tamil" => Some(CharsetLanguage::Tamil),
            "te" | "telugu" => Some(CharsetLanguage::Telugu),
            "kn" | "kannada" => Some(CharsetLanguage::Kannada),
            "ml" | "malayalam" => Some(CharsetLanguage::Malayalam),
            "pa" | "punjabi" | "gurmukhi" => Some(CharsetLanguage::Gurmukhi),
            "si" | "sinhala" => Some(CharsetLanguage::Sinhala),
            _ => None,
        }
    }
    
    pub fn charset(&self) -> &'static str {
        match self {
            CharsetLanguage::Latin => "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+[]{}|;:,.<>?",
            CharsetLanguage::Hungarian => "aábcdeéfghiíjklmnoóöőpqrstuúüűvwxyzAÁBCDEÉFGHIÍJKLMNOÓÖŐPQRSTUÚÜŰVWXYZ0123456789!@#$%^&*",
            CharsetLanguage::Chinese => "的一是不了人我在有他这为之大来以个中上们到说国和地也子时道出会三要于下得可你年生自那后能过对学里用家种23456789!@#$%^&*",
            CharsetLanguage::Japanese => "あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをんアイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン0123456789!@#$%^&*",
            CharsetLanguage::Korean => "가나다라마바사아자차카타파하거너더러머버서어저처커터퍼허고노도로모보소오조초코토포호구누두루무부수우주추쿠투푸후0123456789!@#$%^&*",
            CharsetLanguage::Arabic => "ابتثجحخدذرزسشصضطظعغفقكلمنهوي0123456789!@#$%^&*",
            CharsetLanguage::Hebrew => "אבגדהוזחטיכלמנסעפצקרשת0123456789!@#$%^&*",
            CharsetLanguage::Hindi => "अआइईउऊऋएऐओऔकखगघचछजझटठडढणतथदधनपफबभमयरलवशषसह0123456789!@#$%^&*",
            CharsetLanguage::Bengali => "অআইঈউঊঋএঐওঔকখগঘঙচছজঝঞটঠডঢণতথদধনপফবভমযরলশষসহ0123456789!@#$%^&*",
            CharsetLanguage::Thai => "กขคงจฉชซญฎฏฐฎฒณดตถทธนบปผฝพฟภมยรลวศษสหอฮ0123456789!@#$%^&*",
            CharsetLanguage::Greek => "αβγδεζηθικλμνξοπρστυφχψωΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ0123456789!@#$%^&*",
            CharsetLanguage::Cyrillic => "абвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ0123456789!@#$%^&*",
            CharsetLanguage::Armenian => "աբգդեզէըթժինխլխծկհձղճմյնշոչպջռսվտրցւփքօֆ0123456789!@#$%^&*",
            CharsetLanguage::Georgian => "აბგდევზთიკლმნოპჟრსტუფქღყშჩცძწჭხჯჰ0123456789!@#$%^&*",
            CharsetLanguage::Tamil => "அஆஇஈஉஊஎஏஐஒஓஔகஙசஞடணதநனபமயரறலளழவஷஸஹ0123456789!@#$%^&*",
            CharsetLanguage::Telugu => "అఆఇఈఉఊఋఎఏఐఒఓఔకఖగఘఙచఛజఝఞటఠడఢణతథదధనపఫబభమయరలవశషసహ0123456789!@#$%^&*",
            CharsetLanguage::Kannada => "ಅಆಇಈಉಊಋಎಏಐಒಓಔಕಖಗಘಙಚಛಜಝಞಟಠಡಢಣತಥದಧನಪಫಬಭಮಯರಲವಶಷಸಹ0123456789!@#$%^&*",
            CharsetLanguage::Malayalam => "അആഇഈഉഊഋഎഏഐഒഓഔകഖഗഘങചഛജഝഞടഠഡഢണതഥദധനപഫബഭമയരലവശഷസഹ0123456789!@#$%^&*",
            CharsetLanguage::Gurmukhi => "ਅਆਇਈਉਊਏਐਓਔਕਖਗਘਙਚਛਜਝਞਟਠਡਢਣਤਥਦਧਨਪਫਬਭਮਯਰਲਵਸ਼ਸਹ0123456789!@#$%^&*",
            CharsetLanguage::Sinhala => "අආඇඈඉඊඋඌඍඑඒඓඔඕඖකඛගඝඞඟචඡජඣඤඥඦටඨඩඪණඬතථදධනඳපඵබභමඹයරලවශෂසහ0123456789!@#$%^&*",
        }
    }
}
CHAR_EOF
    echo -e "  ${GREEN}✓${NC} charsets.rs"
    
    # ---------- auto_recovery.rs ----------
    cat > "$SRC_DIR/auto_recovery.rs" << 'RECOVERY_EOF'
//! Fool-proof auto-recovery system - never crashes

use std::path::{Path, PathBuf};
use std::fs;
use colored::*;

#[derive(Debug, Clone, Copy)]
pub enum Severity { Info, Warning, Critical }

#[derive(Debug)]
pub struct RecoveryAction {
    pub problem: String,
    pub solution: String,
    pub severity: Severity,
}

pub struct AutoRecovery {
    fixes: Vec<RecoveryAction>,
}

impl AutoRecovery {
    pub fn new() -> Self {
        Self { fixes: Vec::new() }
    }
    
    pub fn add_fix(&mut self, problem: impl Into<String>, solution: impl Into<String>, severity: Severity) {
        self.fixes.push(RecoveryAction {
            problem: problem.into(),
            solution: solution.into(),
            severity,
        });
    }
    
    pub fn get_safe_filename(&mut self, original: &str) -> PathBuf {
        let path = Path::new(original);
        
        if !path.exists() {
            return path.to_path_buf();
        }
        
        let stem = path.file_stem().unwrap_or_default().to_string_lossy();
        let extension = path.extension().unwrap_or_default().to_string_lossy();
        let parent = path.parent().unwrap_or_else(|| Path::new("."));
        
        for i in 1..=9999 {
            let new_name = format!("{}_{}.{}", stem, i, extension);
            let new_path = parent.join(&new_name);
            
            if !new_path.exists() {
                self.add_fix(
                    format!("File '{}' already exists", original),
                    format!("Auto-renamed to '{}'", new_path.display()),
                    Severity::Warning
                );
                return new_path;
            }
        }
        
        let timestamp = chrono::Local::now().format("%Y%m%d_%H%M%S");
        let final_name = format!("{}_{}.{}", stem, timestamp, extension);
        let final_path = parent.join(&final_name);
        
        self.add_fix(
            format!("File '{}' exists, 9999 variations tried", original),
            format!("Used timestamp-based name: '{}'", final_path.display()),
            Severity::Critical
        );
        
        final_path
    }
    
    pub fn ensure_writable_path(&mut self, path: &Path) -> PathBuf {
        if let Some(parent) = path.parent() {
            if parent.exists() {
                if let Ok(meta) = fs::metadata(parent) {
                    if !meta.permissions().readonly() {
                        return path.to_path_buf();
                    }
                }
            }
        }
        
        let home = std::env::var("HOME")
            .or_else(|_| std::env::var("USERPROFILE"))
            .unwrap_or_else(|_| ".".to_string());
        let fallback_path = PathBuf::from(&home).join(path.file_name().unwrap_or_default());
        
        self.add_fix(
            format!("Cannot write to '{}'", path.display()),
            format!("Fallback to home directory: '{}'", fallback_path.display()),
            Severity::Critical
        );
        
        fallback_path
    }
    
    pub fn ensure_valid_charset(&mut self, charset: &str, fallback_charset: &str) -> String {
        if charset.is_empty() {
            self.add_fix(
                "Character set is empty",
                format!("Using fallback charset ({} chars)", fallback_charset.len()),
                Severity::Critical
            );
            return fallback_charset.to_string();
        }
        charset.to_string()
    }
    
    pub fn ensure_valid_length(&mut self, length: usize) -> usize {
        if length < 1 {
            self.add_fix(format!("Invalid length: {}", length), "Using default 8", Severity::Warning);
            return 8;
        }
        if length > 16000 {
            self.add_fix(format!("Length too long: {}", length), "Using maximum 16000", Severity::Warning);
            return 16000;
        }
        length
    }
    
    pub fn ensure_valid_count(&mut self, count: usize) -> usize {
        if count < 1 {
            self.add_fix(format!("Invalid count: {}", count), "Using default 10", Severity::Warning);
            return 10;
        }
        count
    }
    
    pub fn print_summary(&self) {
        if self.fixes.is_empty() { return; }
        
        println!();
        println!("{}", "╔════════════════════════════════════════════════════════════════╗".yellow().bold());
        println!("{}           {}           {}", "║".yellow().bold(), "AUTOMATIC FIXES APPLIED".yellow().bold(), "║".yellow().bold());
        println!("{}", "╠════════════════════════════════════════════════════════════════╣".yellow().bold());
        
        for (i, fix) in self.fixes.iter().enumerate() {
            let severity_icon = match fix.severity {
                Severity::Info => "ℹ".blue(),
                Severity::Warning => "⚠".yellow(),
                Severity::Critical => "⚠".red().bold(),
            };
            
            println!("{} {} Fix #{} {}", "║".yellow().bold(), severity_icon, i + 1, "║".yellow().bold());
            println!("{}    Problem:  {} {}", "║".yellow().bold(), fix.problem.red(), "║".yellow().bold());
            println!("{}    Solution: {} {}", "║".yellow().bold(), fix.solution.green(), "║".yellow().bold());
            
            if i < self.fixes.len() - 1 {
                println!("{}", "║╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶║".yellow());
            }
        }
        
        println!("{}", "╚════════════════════════════════════════════════════════════════╝".yellow().bold());
        println!();
    }
    
    pub fn has_fixes(&self) -> bool { !self.fixes.is_empty() }
    pub fn fix_count(&self) -> usize { self.fixes.len() }
}
RECOVERY_EOF
    echo -e "  ${GREEN}✓${NC} auto_recovery.rs"
    
    # ---------- config.rs ----------
    cat > "$SRC_DIR/config.rs" << 'CONFIG_EOF'
//! Configuration module

use crate::i18n::Language;
use crate::charsets::CharsetLanguage;
use crate::auto_recovery::AutoRecovery;

#[derive(Debug, Clone)]
pub struct Config {
    pub use_lowercase: bool,
    pub use_uppercase: bool,
    pub use_numbers: bool,
    pub use_symbols: bool,
    pub exclude_ambiguous: bool,
    pub length: usize,
    pub count: usize,
    pub extreme_random: bool,
    pub extreme_iterations: u32,
    pub database_mode: bool,
    pub max_rows: usize,
    pub max_columns: usize,
    pub output_file: String,
    pub auto_rename: bool,
    pub timestamp_filename: bool,
    pub debug_mode: bool,
    pub log_file: Option<String>,
    pub ui_language: Language,
    pub charset_language: CharsetLanguage,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            use_lowercase: true,
            use_uppercase: false,
            use_numbers: false,
            use_symbols: false,
            exclude_ambiguous: false,
            length: 8,
            count: 10,
            extreme_random: false,
            extreme_iterations: 10000,
            database_mode: false,
            max_rows: 1000,
            max_columns: 26,
            output_file: "passwords.csv".to_string(),
            auto_rename: true,
            timestamp_filename: false,
            debug_mode: false,
            log_file: None,
            ui_language: Language::detect_system_language(),
            charset_language: CharsetLanguage::Latin,
        }
    }
}

impl Config {
    pub fn new() -> Self { Self::default() }
    
    pub fn build_charset(&self, recovery: &mut AutoRecovery) -> String {
        let base_charset = self.charset_language.charset();
        let mut charset = String::new();
        
        if self.use_lowercase {
            charset.push_str(&base_charset.chars().filter(|c| c.is_lowercase() || !c.is_alphabetic()).collect::<String>());
        }
        if self.use_uppercase {
            charset.push_str(&base_charset.chars().filter(|c| c.is_uppercase() || !c.is_alphabetic()).collect::<String>());
        }
        if self.use_numbers {
            charset.push_str(&base_charset.chars().filter(|c| c.is_numeric()).collect::<String>());
        }
        if self.use_symbols {
            charset.push_str(&base_charset.chars().filter(|c| !c.is_alphanumeric() && !c.is_whitespace()).collect::<String>());
        }
        
        if charset.is_empty() {
            charset = base_charset.to_string();
        }
        
        if self.exclude_ambiguous {
            let ambiguous = "1lI0Oo";
            charset.retain(|c| !ambiguous.contains(c));
        }
        
        recovery.ensure_valid_charset(&charset, base_charset)
    }
    
    pub fn validate(&mut self, recovery: &mut AutoRecovery) {
        self.length = recovery.ensure_valid_length(self.length);
        self.count = recovery.ensure_valid_count(self.count);
    }
    
    pub fn calculate_grid_dimensions(&mut self) {
        if !self.database_mode { return; }
        
        let total = self.count;
        
        if total <= self.max_rows {
            self.max_columns = 1;
        } else {
            self.max_columns = (total + self.max_rows - 1) / self.max_rows;
            if self.max_columns > 1000 {
                self.max_rows = (total + 1000 - 1) / 1000;
                self.max_columns = 1000;
            }
        }
        
        self.count = self.max_rows * self.max_columns;
    }
}
CONFIG_EOF
    echo -e "  ${GREEN}✓${NC} config.rs"
    
    # ---------- entropy.rs ----------
    cat > "$SRC_DIR/entropy.rs" << 'ENTROPY_EOF'
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
ENTROPY_EOF
    echo -e "  ${GREEN}✓${NC} entropy.rs"
    
    # ---------- csv_writer.rs (FIXED!) ----------
    cat > "$SRC_DIR/csv_writer.rs" << 'CSV_EOF'
//! CSV writer - streaming, memory-efficient

use std::fs::OpenOptions;
use std::io::{BufWriter, Write};
use std::path::PathBuf;
use chrono::Local;
use crate::error::Result;
use crate::config::Config;
use crate::entropy::DeepEntropy;
use crate::plugins::Plugin;
use crate::auto_recovery::AutoRecovery;

pub struct CsvWriter {
    config: Config,
    entropy: DeepEntropy,
}

impl CsvWriter {
    pub fn new(config: Config) -> Self {
        let entropy = DeepEntropy::new(config.extreme_iterations);
        Self { config, entropy }
    }
    
    fn generate_one_password(&self, charset: &str) -> Result<String> {
        if self.config.extreme_random {
            self.entropy.generate_password(self.config.length, charset)
        } else {
            self.entropy.generate_password_standard(self.config.length, charset)
        }
    }
    
    fn csv_escape(value: &str) -> String {
        if value.contains(',') || value.contains('"') || value.contains('\n') {
            let escaped = value.replace('"', "\"\"");
            format!("\"{}\"", escaped)
        } else {
            value.to_string()
        }
    }
    
    fn get_style_string(&self) -> String {
        let mut style = String::new();
        if self.config.use_uppercase { style.push('C'); }
        if self.config.use_numbers { style.push('N'); }
        if self.config.use_symbols { style.push('S'); }
        if self.config.use_lowercase { style.push('L'); }
        if style.is_empty() { style.push('L'); }
        style
    }
    
    pub fn write_standard_csv(&self, plugins: &[Box<dyn Plugin>], recovery: &mut AutoRecovery) -> Result<PathBuf> {
        let output_path = recovery.get_safe_filename(&self.config.output_file);
        let output_path = recovery.ensure_writable_path(&output_path);
        let charset = self.config.build_charset(recovery);
        
        let file = OpenOptions::new()
            .write(true).create(true).truncate(true)
            .open(&output_path)?;
        let mut writer = BufWriter::new(file);
        
        writeln!(writer, "id,password,length,style,timestamp")?;
        let style = self.get_style_string();
        let timestamp = Local::now().to_rfc3339();
        
        for i in 1..=self.config.count {
            let mut password = self.generate_one_password(&charset)?;
            for plugin in plugins {
                password = plugin.process_password(password);
            }
            let escaped_pw = Self::csv_escape(&password);
            writeln!(writer, "{},{},{},{},{}", i, escaped_pw, self.config.length, style, timestamp)?;
            
            if i % 100 == 0 || i == self.config.count {
                self.print_progress(i, self.config.count);
            }
            if i % 1000 == 0 { writer.flush()?; }
        }
        
        writer.flush()?;
        println!();
        Ok(output_path)
    }
    
    pub fn write_database_grid(&self, plugins: &[Box<dyn Plugin>], recovery: &mut AutoRecovery) -> Result<PathBuf> {
        let output_path = recovery.get_safe_filename(&self.config.output_file);
        let output_path = recovery.ensure_writable_path(&output_path);
        let charset = self.config.build_charset(recovery);
        
        let file = OpenOptions::new()
            .write(true).create(true).truncate(true)
            .open(&output_path)?;
        let mut writer = BufWriter::new(file);
        
        let mut header = String::from("Row");
        for col in 1..=self.config.max_columns {
            header.push(',');
            header.push_str(&Self::num_to_column(col));
        }
        writeln!(writer, "{}", header)?;
        
        let total_rows = (self.config.count + self.config.max_columns - 1) / self.config.max_columns;
        for row in 1..=total_rows {
            let mut row_data = row.to_string();
            for _ in 1..=self.config.max_columns {
                let mut password = self.generate_one_password(&charset)?;
                for plugin in plugins {
                    password = plugin.process_password(password);
                }
                row_data.push(',');
                row_data.push_str(&Self::csv_escape(&password));
            }
            writeln!(writer, "{}", row_data)?;
            
            if row % 10 == 0 || row == total_rows {
                self.print_progress(row, total_rows);
            }
            if row % 100 == 0 { writer.flush()?; }
        }
        
        writer.flush()?;
        println!();
        Ok(output_path)
    }
    
    fn num_to_column(num: usize) -> String {
        let mut result = String::new();
        let mut n = num;
        while n > 0 {
            let rem = (n - 1) % 26;
            let ch = (b'A' + rem as u8) as char;
            result.insert(0, ch);
            n = (n - 1) / 26;
        }
        result
    }
    
    fn print_progress(&self, current: usize, total: usize) {
        if total == 0 { return; }
        let width = 40;
        let percentage = current * 100 / total;
        let filled = current * width / total;
        let empty = width - filled;
        print!("\r  [{}{}] {:3}% ({}/{})", "#".repeat(filled), "-".repeat(empty), percentage, current, total);
    }
}
CSV_EOF
    echo -e "  ${GREEN}✓${NC} csv_writer.rs"
    
    # ---------- cli.rs ----------
    cat > "$SRC_DIR/cli.rs" << 'CLI_EOF'
//! CLI argument parser

use clap::Parser;
use crate::config::Config;
use crate::i18n::Language;
use crate::charsets::CharsetLanguage;
use crate::auto_recovery::{AutoRecovery, Severity};

#[derive(Parser, Debug)]
#[command(name = "secure-passgen")]
#[command(version = "3.0.0")]
#[command(about = "Military-grade fool-proof password generator with i18n")]
pub struct Cli {
    #[arg(short = 'c', long = "capitals")]
    pub capitals: bool,
    #[arg(short = 'n', long = "numbers")]
    pub numbers: bool,
    #[arg(short = 's', long = "symbols")]
    pub symbols: bool,
    #[arg(short = 'B', long = "no-ambiguous")]
    pub no_ambiguous: bool,
    #[arg(short = 'l', long = "length", default_value = "8")]
    pub length: usize,
    #[arg(long = "count")]
    pub count: Option<usize>,
    #[arg(value_name = "COUNT_SHORTHAND")]
    pub count_shorthand: Option<String>,
    #[arg(long = "extreme-random")]
    pub extreme_random: bool,
    #[arg(long = "extreme-iter", default_value = "10000")]
    pub extreme_iter: u32,
    #[arg(long = "password-db")]
    pub password_db: bool,
    #[arg(short = 'o', long = "output", default_value = "passwords.csv")]
    pub output: String,
    #[arg(long = "auto-rename", default_value = "true")]
    pub auto_rename: bool,
    #[arg(long = "timestamp")]
    pub timestamp: bool,
    #[arg(long = "debug")]
    pub debug: bool,
    #[arg(long = "log")]
    pub log: Option<String>,
    #[arg(long = "plugins")]
    pub plugins: Option<String>,
    #[arg(long = "language", default_value = "auto")]
    pub language: String,
    #[arg(long = "charset", default_value = "latin")]
    pub charset: String,
}

impl Cli {
    pub fn to_config(&self, recovery: &mut AutoRecovery) -> Config {
        let mut config = Config::new();
        
        if self.language.to_lowercase() != "auto" {
            if let Some(lang) = Language::from_code(&self.language) {
                config.ui_language = lang;
            } else {
                recovery.add_fix(
                    format!("Unknown language: {}", self.language),
                    "Using system default",
                    Severity::Warning
                );
            }
        }
        
        if let Some(charset_lang) = CharsetLanguage::from_code(&self.charset) {
            config.charset_language = charset_lang;
        } else {
            recovery.add_fix(
                format!("Unknown charset: {}", self.charset),
                "Using Latin charset",
                Severity::Warning
            );
        }
        
        config.use_lowercase = true;
        config.use_uppercase = self.capitals;
        config.use_numbers = self.numbers;
        config.use_symbols = self.symbols;
        config.exclude_ambiguous = self.no_ambiguous;
        config.length = self.length;
        config.count = if let Some(count) = self.count {
            count
        } else if let Some(ref shorthand) = self.count_shorthand {
            Self::parse_count_shorthand(shorthand)
        } else {
            10
        };
        config.extreme_random = self.extreme_random;
        config.extreme_iterations = self.extreme_iter;
        config.database_mode = self.password_db;
        config.output_file = self.output.clone();
        config.auto_rename = self.auto_rename;
        config.timestamp_filename = self.timestamp;
        config.debug_mode = self.debug;
        config.log_file = self.log.clone();
        config
    }
    
    fn parse_count_shorthand(s: &str) -> usize {
        let s = s.to_uppercase();
        if s.ends_with('M') {
            let num_str = &s[..s.len()-1];
            num_str.parse().unwrap_or(1) * 1_000_000
        } else if s.ends_with('K') {
            let num_str = &s[..s.len()-1];
            num_str.parse().unwrap_or(1) * 1_000
        } else {
            s.parse().unwrap_or(10)
        }
    }
}
CLI_EOF
    echo -e "  ${GREEN}✓${NC} cli.rs"
    
    # ---------- interactive.rs ----------
    cat > "$SRC_DIR/interactive.rs" << 'INT_EOF'
//! Interactive mode - SSH-style prompts

use dialoguer::{theme::ColorfulTheme, Confirm, Input};
use colored::Colorize;
use crate::config::Config;

pub fn interactive_config(mut config: Config) -> Config {
    println!();
    println!("{}", "  --- INTERACTIVE PASSWORD DATABASE SETUP ---".bold());
    println!();
    
    let theme = ColorfulTheme::default();
    
    let length: usize = Input::with_theme(&theme)
        .with_prompt("  Enter password length")
        .default(8)
        .interact_text()
        .unwrap_or(8);
    config.length = length;
    
    config.use_uppercase = Confirm::with_theme(&theme)
        .with_prompt("  Include Capital Letters?")
        .default(false)
        .interact()
        .unwrap_or(false);
    
    config.use_numbers = Confirm::with_theme(&theme)
        .with_prompt("  Include Numbers?")
        .default(false)
        .interact()
        .unwrap_or(false);
    
    config.use_symbols = Confirm::with_theme(&theme)
        .with_prompt("  Include Symbols?")
        .default(false)
        .interact()
        .unwrap_or(false);
    
    config.extreme_random = Confirm::with_theme(&theme)
        .with_prompt("  Enable Extreme Randomness?")
        .default(false)
        .interact()
        .unwrap_or(false);
    
    if config.extreme_random {
        let iterations: u32 = Input::with_theme(&theme)
            .with_prompt("  Hash iterations (1000-1000000)")
            .default(10000)
            .interact_text()
            .unwrap_or(10000);
        config.extreme_iterations = iterations;
    }
    
    println!();
    config
}
INT_EOF
    echo -e "  ${GREEN}✓${NC} interactive.rs"
    
    # ---------- plugins/mod.rs ----------
    cat > "$SRC_DIR/plugins/mod.rs" << 'PMOD_EOF'
//! Plugin system

pub trait Plugin {
    fn name(&self) -> &str;
    fn description(&self) -> &str;
    fn process_password(&self, password: String) -> String;
}

pub mod uppercase_validator;
pub mod hyphen_formatter;
PMOD_EOF
    echo -e "  ${GREEN}✓${NC} plugins/mod.rs"
    
    # ---------- plugins/uppercase_validator.rs ----------
    cat > "$SRC_DIR/plugins/uppercase_validator.rs" << 'UVAL_EOF'
//! Uppercase Validator Plugin

use super::Plugin;
use rand::Rng;

pub struct UppercaseValidator;

impl UppercaseValidator {
    pub fn new() -> Self { Self }
}

impl Plugin for UppercaseValidator {
    fn name(&self) -> &str { "Uppercase Validator" }
    fn description(&self) -> &str { "Ensures every password has at least one uppercase letter" }
    fn process_password(&self, password: String) -> String {
        if password.chars().any(|c| c.is_uppercase()) {
            return password;
        }
        let uppercase_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        let mut rng = rand::thread_rng();
        let random_char = uppercase_chars.chars().nth(rng.gen_range(0..uppercase_chars.len())).unwrap();
        format!("{}{}", password, random_char)
    }
}
UVAL_EOF
    echo -e "  ${GREEN}✓${NC} plugins/uppercase_validator.rs"
    
    # ---------- plugins/hyphen_formatter.rs ----------
    cat > "$SRC_DIR/plugins/hyphen_formatter.rs" << 'HYPH_EOF'
//! Hyphen Formatter Plugin

use super::Plugin;

pub struct HyphenFormatter { chunk_size: usize }

impl HyphenFormatter {
    pub fn new(chunk_size: usize) -> Self { Self { chunk_size } }
}

impl Plugin for HyphenFormatter {
    fn name(&self) -> &str { "Hyphen Formatter" }
    fn description(&self) -> &str { "Adds hyphens every N characters" }
    fn process_password(&self, password: String) -> String {
        let chars: Vec<char> = password.chars().collect();
        let mut result = String::new();
        for (i, ch) in chars.iter().enumerate() {
            if i > 0 && i % self.chunk_size == 0 {
                result.push('-');
            }
            result.push(*ch);
        }
        result
    }
}
HYPH_EOF
    echo -e "  ${GREEN}✓${NC} plugins/hyphen_formatter.rs"
    
    # ---------- main.rs (FIXED!) ----------
    cat > "$SRC_DIR/main.rs" << 'MAIN_EOF'
//! Secure PassGen - Main entry point (fool-proof)

use clap::Parser;
use colored::*;
use std::time::Instant;
use secure_passgen::{
    cli::Cli,
    config::Config,
    csv_writer::CsvWriter,
    i18n::{Language, Translations},
    auto_recovery::AutoRecovery,
    plugins::{Plugin, uppercase_validator::UppercaseValidator, hyphen_formatter::HyphenFormatter},
};

fn main() {
    if let Err(e) = run() {
        eprintln!("{}", "╔════════════════════════════════════════════════════════════════╗".red().bold());
        eprintln!("{}", "║                    UNEXPECTED ERROR OCCURRED                  ║".red().bold());
        eprintln!("{}", "╠════════════════════════════════════════════════════════════════╣".red().bold());
        eprintln!("║ {} {}", "Message:".bold(), e.to_string().red());
        eprintln!("{}", "╚════════════════════════════════════════════════════════════════╝".red().bold());
        eprintln!();
        eprintln!("{}", "Please try running the program again.".yellow());
        std::process::exit(1);
    }
}

fn run() -> Result<(), Box<dyn std::error::Error>> {
    let start_time = Instant::now();
    
    let cli = Cli::parse();
    let mut recovery = AutoRecovery::new();
    let mut config = cli.to_config(&mut recovery);
    
    let translations = Translations::new(config.ui_language);
    print_banner(&translations);
    print_system_info(&translations);
    
    config.validate(&mut recovery);
    config.calculate_grid_dimensions();
    
    let plugins = load_plugins(&cli);
    print_execution_preview(&config, &plugins);
    
    let writer = CsvWriter::new(config.clone());
    println!("  {}", translations.get("generating").blue().bold());
    
    let output_path = if config.database_mode {
        writer.write_database_grid(&plugins, &mut recovery)?
    } else {
        writer.write_standard_csv(&plugins, &mut recovery)?
    };
    
    let duration = start_time.elapsed();
    println!("{}", "--------------------------------------------------------------------------------".cyan());
    println!("  {} - {} {:.3} seconds",
        translations.get("success").green().bold(),
        translations.get("completed").green(),
        duration.as_secs_f64()
    );
    println!("{}", "================================================================================".cyan());
    println!();
    println!("  {} {}", translations.get("file_saved").green().bold(), output_path.display().to_string().bold());
    
    if recovery.has_fixes() {
        println!();
        println!("{}", "  ⚠ AUTOMATIC RECOVERY ACTIVATED".yellow().bold());
        println!("  {} {}", "Problems found:".yellow(), recovery.fix_count().to_string().yellow().bold());
        recovery.print_summary();
    }
    
    println!();
    println!("  {} {}", "TIP".yellow().bold(), "You can open the CSV file in LibreOffice Calc or Excel.".yellow());
    println!();
    
    Ok(())
}

fn print_banner(translations: &Translations) {
    println!("{}", "================================================================================".cyan());
    println!("  {}  |  Date: {}", translations.get("welcome").bold(), chrono::Local::now().format("%Y-%m-%d"));
    println!("{}", "================================================================================".cyan());
    println!("{}", "--------------------------------------------------------------------------------".cyan());
}

fn print_system_info(translations: &Translations) {
    println!("  {}", "[SYSTEM TELEMETRY]".blue().bold());
    println!("  Date/Time : {}", chrono::Local::now().format("%Y-%m-%d %H:%M:%S %Z"));
    println!("  Hostname  : {}", hostname::get().unwrap_or_default().to_string_lossy());
    println!("  OS        : {}", sys_info::os_release().unwrap_or_else(|_| "Unknown".to_string()));
    println!("  Language  : {}", translations.language().name());
    println!("{}", "--------------------------------------------------------------------------------".cyan());
}

fn print_execution_preview(config: &Config, plugins: &[Box<dyn Plugin>]) {
    println!();
    println!("  {}", "--- EXECUTION PREVIEW ---".bold());
    println!("  Mode           : {}", if config.database_mode { "Password Database Grid".cyan() } else { "Standard CSV List".cyan() });
    println!("  Total Passwords: {}", config.count.to_string().cyan());
    println!("  Length         : {}", config.length.to_string().cyan());
    println!("  Charset        : {}", config.charset_language.name().cyan());
    println!("  UI Language    : {}", config.ui_language.name().cyan());
    
    let mut style = String::new();
    if config.use_uppercase { style.push_str("Capitals "); }
    if config.use_numbers { style.push_str("Numbers "); }
    if config.use_symbols { style.push_str("Symbols "); }
    if config.use_lowercase { style.push_str("Lowers "); }
    println!("  Style          : {}", style.cyan());
    
    println!("  Randomness     : {}", if config.extreme_random {
        format!("Extreme (Deep Hashing {} iter)", config.extreme_iterations).cyan()
    } else {
        "Standard (CSPRNG)".cyan()
    });
    
    println!("  Output File    : {}", config.output_file.cyan());
    
    if !plugins.is_empty() {
        println!("  Plugins        : {}", plugins.iter().map(|p| p.name()).collect::<Vec<_>>().join(", ").cyan());
    }
    
    let est_time = if config.extreme_random {
        let seconds_per_pw = std::cmp::max(1, config.extreme_iterations / 10000);
        config.count * seconds_per_pw as usize
    } else {
        std::cmp::max(1, config.count / 10000)
    };
    println!("  Estimated Time : {}", format!("~{} seconds", est_time).yellow());
    println!("{}", "--------------------------------------------------------------------------------".cyan());
}

fn load_plugins(cli: &Cli) -> Vec<Box<dyn Plugin>> {
    let mut plugins: Vec<Box<dyn Plugin>> = Vec::new();
    if let Some(ref plugin_list) = cli.plugins {
        for plugin_name in plugin_list.split(',') {
            let plugin_name = plugin_name.trim().to_lowercase();
            match plugin_name.as_str() {
                "uppercase" => {
                    println!("  {} Loading plugin: Uppercase Validator", "INFO".blue().bold());
                    plugins.push(Box::new(UppercaseValidator::new()));
                }
                "hyphen" => {
                    println!("  {} Loading plugin: Hyphen Formatter", "INFO".blue().bold());
                    plugins.push(Box::new(HyphenFormatter::new(4)));
                }
                _ => {
                    println!("  {} Unknown plugin: {} (skipping)", "WARNING".yellow().bold(), plugin_name);
                }
            }
        }
    }
    plugins
}
MAIN_EOF
    echo -e "  ${GREEN}✓${NC} main.rs"
}

run_build() {
    echo -e "${BOLD}[6/7] Running cargo build --release...${NC}"
    echo
    
    cd "$PROJECT_DIR"
    
    if cargo build --release 2>&1 | tee /tmp/build_output.log; then
        echo
        echo -e "${GREEN}✓ Build successful!${NC}"
    else
        echo
        echo -e "${RED}✗ Build failed! Check /tmp/build_output.log${NC}"
        return 1
    fi
}

print_final_summary() {
    echo
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}${GREEN}PROJECT BUILT SUCCESSFULLY${NC}                                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${BOLD}Binary:${NC} $PROJECT_DIR/target/release/secure-passgen"
    echo -e "${BOLD}Backup:${NC} $BACKUP_DIR"
    echo
    echo -e "${BOLD}Test commands:${NC}"
    echo "  ./target/release/secure-passgen --help"
    echo "  ./target/release/secure-passgen -c -n -s -l 16"
    echo "  ./target/release/secure-passgen --language hu -c -n -s -l 16"
    echo "  ./target/release/secure-passgen --charset chinese -l 12"
    echo "  ./target/release/secure-passgen --password-db -c -n -1M -o db.csv"
    echo
}

# Main execution
print_banner
check_prerequisites
backup_old_source
create_directory_structure
generate_cargo_toml
generate_source_files
run_build && print_final_summary
