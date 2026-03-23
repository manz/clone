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
    weight: FontWeight,
    is_icon: bool,
}

struct TextState {
    font_system: FontSystem,
    cache: FxHashMap<MeasureKey, TextSize>,
}

static STATE: Mutex<Option<TextState>> = Mutex::new(None);

fn with_state<R>(f: impl FnOnce(&mut TextState) -> R) -> R {
    let mut guard = STATE.lock().unwrap();
    if guard.is_none() {
        let mut fs = FontSystem::new();
        fs.db_mut()
            .load_font_data(include_bytes!("../../engine/assets/Inter.ttf").to_vec());
        fs.db_mut()
            .load_font_data(include_bytes!("../../engine/assets/Phosphor.ttf").to_vec());
        *guard = Some(TextState {
            font_system: fs,
            cache: FxHashMap::default(),
        });
    }
    f(guard.as_mut().unwrap())
}

/// Measure text using cosmic-text. Results are cached by (text, fontSize, weight, isIcon).
#[uniffi::export]
pub fn measure_text(
    content: String,
    font_size: f32,
    weight: FontWeight,
    is_icon: bool,
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
        weight: weight.clone(),
        is_icon,
    };

    with_state(|state| {
        // Cache hit
        if let Some(cached) = state.cache.get(&key) {
            return cached.clone();
        }

        // Cache miss — measure with cosmic-text
        let metrics = Metrics::new(font_size, font_size * 1.2);
        let mut buffer = Buffer::new(&mut state.font_system, metrics);

        let cosmic_weight = match &weight {
            FontWeight::Regular => Weight::NORMAL,
            FontWeight::Medium => Weight(500),
            FontWeight::Semibold => Weight::SEMIBOLD,
            FontWeight::Bold => Weight::BOLD,
        };
        let family = if is_icon {
            Family::Name("Phosphor")
        } else {
            Family::Name("Inter Variable")
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

/// Clear the measurement cache (e.g. on font change).
#[uniffi::export]
pub fn clear_text_cache() {
    with_state(|state| {
        state.cache.clear();
    });
}
