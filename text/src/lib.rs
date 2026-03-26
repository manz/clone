use std::sync::Mutex;

use cosmic_text::{Attrs, Buffer, Family, FontSystem, Metrics, Shaping, Weight};
use rustc_hash::FxHashMap;

uniffi::setup_scaffolding!();

/// Font weight enum — matches Clone's SwiftUI.FontWeight.
#[derive(Clone, Debug, PartialEq, Eq, Hash, uniffi::Enum)]
pub enum FontWeight {
    Regular,
    Medium,
    Semibold,
    Bold,
}

/// Result of measuring text.
#[derive(Clone, Debug, uniffi::Record)]
pub struct TextSize {
    pub width: f32,
    pub height: f32,
}

/// Cache key for text measurements.
#[derive(Clone, PartialEq, Eq, Hash)]
struct MeasureKey {
    text: String,
    /// font_size as bits for exact comparison
    font_size_bits: u32,
    /// max_width as bits (None = no wrapping)
    max_width_bits: Option<u32>,
    weight: FontWeight,
}

struct TextState {
    font_system: FontSystem,
    cache: FxHashMap<MeasureKey, TextSize>,
}

static STATE: Mutex<Option<TextState>> = Mutex::new(None);

fn with_state<R>(f: impl FnOnce(&mut TextState) -> R) -> R {
    let mut guard = STATE.lock().unwrap();
    if guard.is_none() {
        // Empty font DB — only bundled Inter (static per-weight), no system font fallback
        let mut db = cosmic_text::fontdb::Database::new();
        db.load_font_data(include_bytes!("../../engine/assets/Inter-Regular.ttf").to_vec());
        db.load_font_data(include_bytes!("../../engine/assets/Inter-Medium.ttf").to_vec());
        db.load_font_data(include_bytes!("../../engine/assets/Inter-SemiBold.ttf").to_vec());
        db.load_font_data(include_bytes!("../../engine/assets/Inter-Bold.ttf").to_vec());
        let fs = FontSystem::new_with_locale_and_db("en-US".to_string(), db);
        *guard = Some(TextState {
            font_system: fs,
            cache: FxHashMap::default(),
        });
    }
    f(guard.as_mut().unwrap())
}

/// Measure text using cosmic-text. Results are cached by (text, fontSize, weight, maxWidth).
/// When max_width is Some, word wrapping is enabled.
#[uniffi::export]
pub fn measure_text(
    content: String,
    font_size: f32,
    weight: FontWeight,
    max_width: Option<f32>,
) -> TextSize {
    if content.is_empty() {
        return TextSize {
            width: 0.0,
            height: font_size * 1.2,
        };
    }

    let key = MeasureKey {
        text: content.clone(),
        font_size_bits: font_size.to_bits(),
        max_width_bits: max_width.map(|w| w.to_bits()),
        weight: weight.clone(),
    };

    with_state(|state| {
        // Cache hit
        if let Some(cached) = state.cache.get(&key) {
            return cached.clone();
        }

        // Cache miss — measure with cosmic-text
        let metrics = Metrics::new(font_size, font_size * 1.2);
        let mut buffer = Buffer::new(&mut state.font_system, metrics);
        // Enable word wrapping if max_width is set
        if let Some(mw) = max_width {
            buffer.set_size(&mut state.font_system, Some(mw), None);
        }

        // Static Inter fonts register with different family names per weight
        let (family, cosmic_weight) = match &weight {
            FontWeight::Regular => (Family::Name("Inter"), Weight::NORMAL),
            FontWeight::Medium => (Family::Name("Inter Medium"), Weight(500)),
            FontWeight::Semibold => (Family::Name("Inter SemiBold"), Weight::SEMIBOLD),
            FontWeight::Bold => (Family::Name("Inter"), Weight::BOLD),
        };
        let attrs = Attrs::new().family(family).weight(cosmic_weight);
        buffer.set_text(&mut state.font_system, &content, attrs, Shaping::Advanced);
        buffer.shape_until_scroll(&mut state.font_system, false);

        let mut total_width: f32 = 0.0;
        let mut total_height: f32 = 0.0;

        for run in buffer.layout_runs() {
            let run_width = run.glyphs.last().map_or(0.0, |g| g.x + g.w);
            total_width = total_width.max(run_width);
            total_height += run.line_height;
        }

        if total_height == 0.0 {
            total_height = font_size * 1.2;
        }

        let result = TextSize {
            width: total_width.ceil(),
            height: total_height.ceil(),
        };

        state.cache.insert(key, result.clone());
        result
    })
}

/// Cursor position within a (possibly wrapped) text block.
#[derive(Clone, Debug, uniffi::Record)]
pub struct CursorPosition {
    pub x: f32,
    pub y: f32,
    pub height: f32,
}

/// Find the pixel position of a cursor at the given character offset within
/// a (possibly wrapped) text block. Returns (x, y) relative to the text
/// block's top-left corner, plus the line height at that position.
#[uniffi::export]
pub fn cursor_position(
    content: String,
    char_offset: u32,
    font_size: f32,
    weight: FontWeight,
    max_width: Option<f32>,
) -> CursorPosition {
    let default_height = font_size * 1.2;

    if content.is_empty() {
        return CursorPosition { x: 0.0, y: 0.0, height: default_height };
    }

    let byte_off: usize = content
        .char_indices()
        .nth(char_offset as usize)
        .map(|(i, _)| i)
        .unwrap_or(content.len());

    with_state(|state| {
        let metrics = Metrics::new(font_size, font_size * 1.2);
        let mut buffer = Buffer::new(&mut state.font_system, metrics);

        if let Some(mw) = max_width {
            buffer.set_size(&mut state.font_system, Some(mw), None);
        }

        let (family, cosmic_weight) = match &weight {
            FontWeight::Regular => (Family::Name("Inter"), Weight::NORMAL),
            FontWeight::Medium => (Family::Name("Inter Medium"), Weight(500)),
            FontWeight::Semibold => (Family::Name("Inter SemiBold"), Weight::SEMIBOLD),
            FontWeight::Bold => (Family::Name("Inter"), Weight::BOLD),
        };
        let attrs = Attrs::new().family(family).weight(cosmic_weight);
        buffer.set_text(&mut state.font_system, &content, attrs, Shaping::Advanced);
        buffer.shape_until_scroll(&mut state.font_system, false);

        let mut line_top = 0.0_f32;
        let mut last_x = 0.0_f32;
        let mut last_y = 0.0_f32;
        let mut last_h = default_height;

        for run in buffer.layout_runs() {
            last_h = run.line_height;

            for glyph in run.glyphs.iter() {
                if byte_off < glyph.end {
                    return CursorPosition { x: glyph.x, y: line_top, height: run.line_height };
                }
            }

            last_x = run.glyphs.last().map_or(0.0, |g| g.x + g.w);
            last_y = line_top;
            line_top += run.line_height;
        }

        CursorPosition { x: last_x, y: last_y, height: last_h }
    })
}

/// Clear the measurement cache (e.g. on font change).
#[uniffi::export]
pub fn clear_text_cache() {
    with_state(|state| {
        state.cache.clear();
    });
}
