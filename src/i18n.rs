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
