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
