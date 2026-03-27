use std::sync::Mutex;

use cosmic_text::{Attrs, Buffer, Family, FontSystem, Metrics, Shaping, Weight};
use rustc_hash::FxHashMap;

uniffi::setup_scaffolding!();

/// Font weight enum — matches Apple's full Font.Weight range.
#[derive(Clone, Debug, PartialEq, Eq, Hash, uniffi::Enum)]
pub enum FontWeight {
    UltraLight,
    Thin,
    Light,
    Regular,
    Medium,
    Semibold,
    Bold,
    Heavy,
    Black,
}

/// Result of measuring text.
#[derive(Clone, Debug, uniffi::Record)]
pub struct TextSize {
    pub width: f32,
    pub height: f32,
}

/// A single glyph's position and string mapping.
#[derive(Clone, Debug, uniffi::Record)]
pub struct GlyphInfo {
    pub x: f32,
    pub width: f32,
    pub string_index: u32,
}

/// A single visual line after wrapping.
#[derive(Clone, Debug, uniffi::Record)]
pub struct TextLayoutLine {
    pub glyphs: Vec<GlyphInfo>,
    pub origin_y: f32,
    pub line_height: f32,
    pub string_range_start: u32,
    pub string_range_end: u32,
}

/// Full multi-line text layout result.
#[derive(Clone, Debug, uniffi::Record)]
pub struct TextLayout {
    pub lines: Vec<TextLayoutLine>,
    pub width: f32,
    pub height: f32,
}

/// Font info returned by font matching.
#[derive(Clone, Debug, uniffi::Record)]
pub struct FontInfo {
    pub family: String,
    pub weight: FontWeight,
    pub available: bool,
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
    family: Option<String>,
}

struct TextState {
    font_system: FontSystem,
    cache: FxHashMap<MeasureKey, TextSize>,
}

static STATE: Mutex<Option<TextState>> = Mutex::new(None);

/// Build the shared font database with bundled Inter fonts + system fonts.
fn build_font_db() -> cosmic_text::fontdb::Database {
    let mut db = cosmic_text::fontdb::Database::new();
    db.load_font_data(include_bytes!("../../engine/assets/Inter-Regular.ttf").to_vec());
    db.load_font_data(include_bytes!("../../engine/assets/Inter-Medium.ttf").to_vec());
    db.load_font_data(include_bytes!("../../engine/assets/Inter-SemiBold.ttf").to_vec());
    db.load_font_data(include_bytes!("../../engine/assets/Inter-Bold.ttf").to_vec());
    // Load system fonts from standard paths
    for path in &[
        "/System/Library/Fonts",
        "/Library/Fonts",
    ] {
        let p = std::path::Path::new(path);
        if p.exists() {
            db.load_fonts_dir(p);
        }
    }
    // User-local fonts
    if let Some(home) = std::env::var_os("HOME") {
        let home = std::path::PathBuf::from(home);
        let user_fonts = home.join("Library/Fonts");
        if user_fonts.exists() {
            db.load_fonts_dir(&user_fonts);
        }
        // Clone-specific font directory — create if missing so users can drop fonts in
        let clone_fonts = home.join(".clone/Library/Fonts");
        let _ = std::fs::create_dir_all(&clone_fonts);
        if clone_fonts.exists() {
            db.load_fonts_dir(&clone_fonts);
        }
    }
    db
}

fn with_state<R>(f: impl FnOnce(&mut TextState) -> R) -> R {
    let mut guard = STATE.lock().unwrap();
    if guard.is_none() {
        let db = build_font_db();
        let fs = FontSystem::new_with_locale_and_db("en-US".to_string(), db);
        *guard = Some(TextState {
            font_system: fs,
            cache: FxHashMap::default(),
        });
    }
    f(guard.as_mut().unwrap())
}

/// Create a new FontSystem with the shared font database.
/// Used by the render crate to get its own instance with identical fonts.
pub fn create_font_system() -> FontSystem {
    let db = build_font_db();
    FontSystem::new_with_locale_and_db("en-US".to_string(), db)
}

/// Access the shared FontSystem for measurement operations.
pub fn with_font_system<R>(f: impl FnOnce(&mut FontSystem) -> R) -> R {
    with_state(|state| f(&mut state.font_system))
}

/// Map FontWeight to cosmic-text family name and Weight.
fn weight_to_cosmic(weight: &FontWeight) -> (Family<'static>, Weight) {
    match weight {
        FontWeight::UltraLight => (Family::Name("Inter"), Weight(100)),
        FontWeight::Thin => (Family::Name("Inter"), Weight(200)),
        FontWeight::Light => (Family::Name("Inter"), Weight(300)),
        FontWeight::Regular => (Family::Name("Inter"), Weight::NORMAL),
        FontWeight::Medium => (Family::Name("Inter Medium"), Weight(500)),
        FontWeight::Semibold => (Family::Name("Inter SemiBold"), Weight::SEMIBOLD),
        FontWeight::Bold => (Family::Name("Inter"), Weight::BOLD),
        FontWeight::Heavy => (Family::Name("Inter"), Weight(800)),
        FontWeight::Black => (Family::Name("Inter"), Weight(900)),
    }
}

/// Map FontWeight to cosmic-text attrs, optionally with a custom family name.
fn make_attrs(weight: &FontWeight, family_name: Option<&str>) -> Attrs<'static> {
    let (default_family, cosmic_weight) = weight_to_cosmic(weight);
    let family = match family_name {
        Some(name) => Family::Name(Box::leak(name.to_string().into_boxed_str())),
        None => default_family,
    };
    Attrs::new().family(family).weight(cosmic_weight)
}

/// Measure text using cosmic-text. Results are cached by (text, fontSize, weight, maxWidth).
/// When max_width is Some, word wrapping is enabled at word boundaries.
#[uniffi::export]
pub fn measure_text(
    content: String,
    font_size: f32,
    weight: FontWeight,
    max_width: Option<f32>,
) -> TextSize {
    measure_text_with_family(content, font_size, weight, max_width, None)
}

/// Measure text with an optional font family name.
#[uniffi::export]
pub fn measure_text_with_family(
    content: String,
    font_size: f32,
    weight: FontWeight,
    max_width: Option<f32>,
    family: Option<String>,
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
        family: family.clone(),
    };

    with_state(|state| {
        if let Some(cached) = state.cache.get(&key) {
            return cached.clone();
        }

        let metrics = Metrics::new(font_size, font_size * 1.2);
        let mut buffer = Buffer::new(&mut state.font_system, metrics);
        if let Some(mw) = max_width {
            buffer.set_size(&mut state.font_system, Some(mw), None);
        }

        let attrs = make_attrs(&weight, family.as_deref());
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

/// Layout text into lines with wrapping, returning structured glyph data.
#[uniffi::export]
pub fn layout_text(
    content: String,
    font_size: f32,
    weight: FontWeight,
    max_width: f32,
) -> TextLayout {
    if content.is_empty() {
        return TextLayout {
            lines: vec![],
            width: 0.0,
            height: font_size * 1.2,
        };
    }

    with_state(|state| {
        let metrics = Metrics::new(font_size, font_size * 1.2);
        let mut buffer = Buffer::new(&mut state.font_system, metrics);
        buffer.set_size(&mut state.font_system, Some(max_width), None);

        let attrs = make_attrs(&weight, None);
        buffer.set_text(&mut state.font_system, &content, attrs, Shaping::Advanced);
        buffer.shape_until_scroll(&mut state.font_system, false);

        let mut lines = Vec::new();
        let mut total_width: f32 = 0.0;
        let mut origin_y: f32 = 0.0;

        for run in buffer.layout_runs() {
            let mut glyphs = Vec::new();
            let mut range_start = u32::MAX;
            let mut range_end = 0u32;

            for glyph in run.glyphs.iter() {
                // Convert byte offset to char offset
                let char_idx = content[..glyph.start.min(content.len())]
                    .chars()
                    .count() as u32;
                glyphs.push(GlyphInfo {
                    x: glyph.x,
                    width: glyph.w,
                    string_index: char_idx,
                });
                range_start = range_start.min(char_idx);
                let end_char_idx = content[..glyph.end.min(content.len())]
                    .chars()
                    .count() as u32;
                range_end = range_end.max(end_char_idx);
            }

            if range_start == u32::MAX {
                range_start = 0;
            }

            let run_width = run.glyphs.last().map_or(0.0, |g| g.x + g.w);
            total_width = total_width.max(run_width);

            lines.push(TextLayoutLine {
                glyphs,
                origin_y,
                line_height: run.line_height,
                string_range_start: range_start,
                string_range_end: range_end,
            });

            origin_y += run.line_height;
        }

        TextLayout {
            lines,
            width: total_width.ceil(),
            height: if origin_y == 0.0 { font_size * 1.2 } else { origin_y.ceil() },
        }
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

        let attrs = make_attrs(&weight, None);
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

/// List all available font family names.
#[uniffi::export]
pub fn list_font_families() -> Vec<String> {
    with_state(|state| {
        let mut families: Vec<String> = state.font_system.db()
            .faces()
            .filter_map(|face| {
                face.families.first().map(|(name, _)| name.clone())
            })
            .collect();
        families.sort();
        families.dedup();
        families
    })
}

/// Resolve a font family name — returns info about whether it's available.
#[uniffi::export]
pub fn resolve_font(family: String, weight: FontWeight) -> FontInfo {
    with_state(|state| {
        let available = state.font_system.db()
            .faces()
            .any(|face| {
                face.families.iter().any(|(name, _)| name == &family)
            });
        FontInfo {
            family: if available { family } else { "Inter".to_string() },
            weight,
            available,
        }
    })
}

/// Clear the measurement cache (e.g. on font change).
#[uniffi::export]
pub fn clear_text_cache() {
    with_state(|state| {
        state.cache.clear();
    });
}
