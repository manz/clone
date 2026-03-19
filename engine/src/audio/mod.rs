pub mod commands;

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use commands::AudioCommand;

/// Audio engine stub. On Linux, this will use CPAL + PipeWire.
/// Currently a no-op that validates commands and tracks state.
pub struct AudioEngine {
    master_volume: f32,
    running: Arc<AtomicBool>,
    sounds_played: Vec<String>,
}

impl AudioEngine {
    pub fn new() -> Self {
        Self {
            master_volume: 1.0,
            running: Arc::new(AtomicBool::new(true)),
            sounds_played: Vec::new(),
        }
    }

    pub fn process_command(&mut self, command: AudioCommand) {
        match command {
            AudioCommand::PlaySound { name, volume: _ } => {
                log::debug!("Playing sound: {name}");
                self.sounds_played.push(name);
            }
            AudioCommand::StopSound { name } => {
                log::debug!("Stopping sound: {name}");
                self.sounds_played.retain(|s| s != &name);
            }
            AudioCommand::SetMasterVolume { volume } => {
                self.master_volume = volume.clamp(0.0, 1.0);
            }
        }
    }

    pub fn master_volume(&self) -> f32 {
        self.master_volume
    }

    pub fn is_running(&self) -> bool {
        self.running.load(Ordering::Relaxed)
    }

    pub fn shutdown(&self) {
        self.running.store(false, Ordering::Relaxed);
    }
}

impl Drop for AudioEngine {
    fn drop(&mut self) {
        self.shutdown();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn audio_engine_creates() {
        let engine = AudioEngine::new();
        assert_eq!(engine.master_volume(), 1.0);
        assert!(engine.is_running());
    }

    #[test]
    fn set_master_volume_clamps() {
        let mut engine = AudioEngine::new();
        engine.process_command(AudioCommand::SetMasterVolume { volume: 2.0 });
        assert_eq!(engine.master_volume(), 1.0);
        engine.process_command(AudioCommand::SetMasterVolume { volume: -0.5 });
        assert_eq!(engine.master_volume(), 0.0);
        engine.process_command(AudioCommand::SetMasterVolume { volume: 0.7 });
        assert_eq!(engine.master_volume(), 0.7);
    }

    #[test]
    fn play_and_stop_tracks_sounds() {
        let mut engine = AudioEngine::new();
        engine.process_command(AudioCommand::PlaySound {
            name: "click".into(),
            volume: 1.0,
        });
        assert_eq!(engine.sounds_played.len(), 1);
        engine.process_command(AudioCommand::StopSound {
            name: "click".into(),
        });
        assert!(engine.sounds_played.is_empty());
    }

    #[test]
    fn shutdown_stops_engine() {
        let engine = AudioEngine::new();
        engine.shutdown();
        assert!(!engine.is_running());
    }
}
