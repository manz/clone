/// UniFFI-exported types for the audio engine.

#[derive(Clone, Debug, PartialEq, uniffi::Enum)]
pub enum PlaybackState {
    Idle,
    Loading,
    ReadyToPlay,
    Playing,
    Paused,
    Stopped,
    Failed { reason: String },
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct TrackMetadata {
    pub title: Option<String>,
    pub artist: Option<String>,
    pub album: Option<String>,
    pub duration_seconds: f64,
}

#[derive(Clone, Debug, thiserror::Error, uniffi::Error)]
pub enum AudioError {
    #[error("File not found: {path}")]
    FileNotFound { path: String },
    #[error("Unsupported audio format")]
    UnsupportedFormat,
    #[error("Decoding failed: {reason}")]
    DecodingFailed { reason: String },
    #[error("Output device failed: {reason}")]
    OutputDeviceFailed { reason: String },
}

#[uniffi::export(callback_interface)]
pub trait AudioPlayerDelegate: Send + Sync {
    fn on_state_changed(&self, state: PlaybackState);
    fn on_time_update(&self, current_seconds: f64, duration_seconds: f64);
    fn on_did_finish_playing(&self);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn playback_state_variants() {
        let states = vec![
            PlaybackState::Idle,
            PlaybackState::Loading,
            PlaybackState::ReadyToPlay,
            PlaybackState::Playing,
            PlaybackState::Paused,
            PlaybackState::Stopped,
            PlaybackState::Failed {
                reason: "test".into(),
            },
        ];
        assert_eq!(states.len(), 7);
    }

    #[test]
    fn track_metadata_defaults() {
        let meta = TrackMetadata {
            title: Some("Song".into()),
            artist: None,
            album: None,
            duration_seconds: 180.0,
        };
        assert_eq!(meta.title.as_deref(), Some("Song"));
        assert_eq!(meta.duration_seconds, 180.0);
    }

    #[test]
    fn audio_error_display() {
        let err = AudioError::FileNotFound {
            path: "/tmp/missing.mp3".into(),
        };
        assert!(err.to_string().contains("/tmp/missing.mp3"));

        let err = AudioError::UnsupportedFormat;
        assert_eq!(err.to_string(), "Unsupported audio format");
    }
}
