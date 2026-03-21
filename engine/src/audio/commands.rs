/// Audio commands sent from Swift to the Rust audio engine.

#[derive(Clone, Debug, PartialEq, uniffi::Enum)]
pub enum AudioCommand {
    PlaySystemSound { name: String, volume: f32 },
    StopSystemSound { name: String },
    SetMasterVolume { volume: f32 },
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn audio_command_play() {
        let cmd = AudioCommand::PlaySystemSound {
            name: "click".into(),
            volume: 0.8,
        };
        if let AudioCommand::PlaySystemSound { name, volume } = cmd {
            assert_eq!(name, "click");
            assert_eq!(volume, 0.8);
        }
    }

    #[test]
    fn audio_command_equality() {
        let a = AudioCommand::SetMasterVolume { volume: 0.5 };
        let b = AudioCommand::SetMasterVolume { volume: 0.5 };
        assert_eq!(a, b);
    }

    #[test]
    fn audio_command_variants() {
        let commands: Vec<AudioCommand> = vec![
            AudioCommand::PlaySystemSound {
                name: "alert".into(),
                volume: 1.0,
            },
            AudioCommand::StopSystemSound {
                name: "alert".into(),
            },
            AudioCommand::SetMasterVolume { volume: 0.7 },
        ];
        assert_eq!(commands.len(), 3);
    }
}
