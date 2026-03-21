/// AudioPlayer — UniFFI-exported object that orchestrates decoding + output.

use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;
use std::thread;

use parking_lot::Mutex;
use ringbuf::traits::Producer;

use crate::decoder::AudioDecoder;
use crate::ffi::{AudioError, AudioPlayerDelegate, PlaybackState, TrackMetadata};
use crate::output::AudioOutput;

#[derive(uniffi::Object)]
pub struct AudioPlayer {
    state: Mutex<PlaybackState>,
    metadata: TrackMetadata,
    path: String,
    volume: Arc<Mutex<f32>>,
    // Current playback position in samples (updated by decode thread)
    position_samples: Arc<AtomicU64>,
    sample_rate: u32,
    channels: u16,
    duration_seconds: f64,
    delegate: Arc<dyn AudioPlayerDelegate>,
    // Signals the decode thread to stop
    stop_flag: Arc<AtomicBool>,
    // Output stream (kept alive to maintain CPAL callback)
    output: Mutex<Option<AudioOutput>>,
    // Decode thread handle
    decode_handle: Mutex<Option<thread::JoinHandle<()>>>,
}

#[uniffi::export]
impl AudioPlayer {
    #[uniffi::constructor]
    pub fn open(
        path: String,
        delegate: Box<dyn AudioPlayerDelegate>,
    ) -> Result<Arc<Self>, AudioError> {
        let decoder = AudioDecoder::open(&path)?;
        let metadata = decoder.metadata();
        let sample_rate = decoder.sample_rate();
        let channels = decoder.channels();
        let duration = decoder.duration().unwrap_or(0.0);

        // Drop the decoder — we'll reopen it on play() to keep things simple
        drop(decoder);

        let delegate: Arc<dyn AudioPlayerDelegate> = Arc::from(delegate);
        let player = Arc::new(Self {
            state: Mutex::new(PlaybackState::ReadyToPlay),
            metadata,
            path,
            volume: Arc::new(Mutex::new(1.0)),
            position_samples: Arc::new(AtomicU64::new(0)),
            sample_rate,
            channels,
            duration_seconds: duration,
            delegate: delegate.clone(),
            stop_flag: Arc::new(AtomicBool::new(false)),
            output: Mutex::new(None),
            decode_handle: Mutex::new(None),
        });

        delegate.on_state_changed(PlaybackState::ReadyToPlay);

        Ok(player)
    }

    pub fn play(&self) -> Result<(), AudioError> {
        let current_state = self.state.lock().clone();
        match current_state {
            PlaybackState::Paused => {
                // Resume — just unpause the stream
                if let Some(out) = self.output.lock().as_ref() {
                    out.play();
                }
                self.set_state(PlaybackState::Playing);
                return Ok(());
            }
            PlaybackState::ReadyToPlay | PlaybackState::Stopped => {
                // Start fresh
            }
            PlaybackState::Playing => return Ok(()),
            _ => return Ok(()),
        }

        self.stop_flag.store(false, Ordering::Relaxed);
        self.position_samples.store(0, Ordering::Relaxed);

        // Open decoder fresh
        let mut decoder = AudioDecoder::open(&self.path)?;

        // Create output stream
        let (output, producer) =
            AudioOutput::new(self.sample_rate, self.channels, self.volume.clone())?;
        output.play();

        *self.output.lock() = Some(output);

        // Spawn decode thread
        let stop_flag = self.stop_flag.clone();
        let position = self.position_samples.clone();
        let delegate = self.delegate.clone();
        let duration = self.duration_seconds;
        let sample_rate = self.sample_rate;
        let channels = self.channels as u64;

        let handle = thread::spawn(move || {
            decode_loop(
                &mut decoder,
                producer,
                stop_flag,
                position,
                delegate,
                duration,
                sample_rate,
                channels,
            );
        });

        *self.decode_handle.lock() = Some(handle);
        self.set_state(PlaybackState::Playing);

        Ok(())
    }

    pub fn pause(&self) {
        if let Some(out) = self.output.lock().as_ref() {
            out.pause();
        }
        self.set_state(PlaybackState::Paused);
    }

    pub fn stop(&self) {
        self.stop_flag.store(true, Ordering::Relaxed);
        if let Some(out) = self.output.lock().as_ref() {
            out.stop();
        }
        // Wait for decode thread
        if let Some(handle) = self.decode_handle.lock().take() {
            let _ = handle.join();
        }
        *self.output.lock() = None;
        self.position_samples.store(0, Ordering::Relaxed);
        self.set_state(PlaybackState::Stopped);
    }

    pub fn seek(&self, seconds: f64) -> Result<(), AudioError> {
        // Stop current playback, reopen at new position
        let was_playing = matches!(*self.state.lock(), PlaybackState::Playing);

        self.stop_flag.store(true, Ordering::Relaxed);
        if let Some(out) = self.output.lock().as_ref() {
            out.stop();
        }
        if let Some(handle) = self.decode_handle.lock().take() {
            let _ = handle.join();
        }
        *self.output.lock() = None;

        // Update position
        let new_pos = (seconds * self.sample_rate as f64 * self.channels as f64) as u64;
        self.position_samples.store(new_pos, Ordering::Relaxed);

        if was_playing {
            self.stop_flag.store(false, Ordering::Relaxed);

            let mut decoder = AudioDecoder::open(&self.path)?;
            decoder.seek(seconds);

            let (output, producer) =
                AudioOutput::new(self.sample_rate, self.channels, self.volume.clone())?;
            output.play();

            *self.output.lock() = Some(output);

            let stop_flag = self.stop_flag.clone();
            let position = self.position_samples.clone();
            let delegate = self.delegate.clone();
            let duration = self.duration_seconds;
            let sample_rate = self.sample_rate;
            let channels = self.channels as u64;

            let handle = thread::spawn(move || {
                decode_loop(
                    &mut decoder,
                    producer,
                    stop_flag,
                    position,
                    delegate,
                    duration,
                    sample_rate,
                    channels,
                );
            });

            *self.decode_handle.lock() = Some(handle);
            self.set_state(PlaybackState::Playing);
        }

        Ok(())
    }

    pub fn set_volume(&self, volume: f32) {
        *self.volume.lock() = volume.clamp(0.0, 1.0);
    }

    pub fn volume(&self) -> f32 {
        *self.volume.lock()
    }

    pub fn duration(&self) -> f64 {
        self.duration_seconds
    }

    pub fn current_time(&self) -> f64 {
        let samples = self.position_samples.load(Ordering::Relaxed);
        if self.sample_rate == 0 || self.channels == 0 {
            return 0.0;
        }
        samples as f64 / (self.sample_rate as f64 * self.channels as f64)
    }

    pub fn state(&self) -> PlaybackState {
        self.state.lock().clone()
    }

    pub fn metadata(&self) -> TrackMetadata {
        self.metadata.clone()
    }
}

impl AudioPlayer {
    fn set_state(&self, new_state: PlaybackState) {
        *self.state.lock() = new_state.clone();
        self.delegate.on_state_changed(new_state);
    }
}

impl Drop for AudioPlayer {
    fn drop(&mut self) {
        self.stop_flag.store(true, Ordering::Relaxed);
        if let Some(out) = self.output.lock().as_ref() {
            out.stop();
        }
        if let Some(handle) = self.decode_handle.lock().take() {
            let _ = handle.join();
        }
    }
}

fn decode_loop(
    decoder: &mut AudioDecoder,
    mut producer: crate::output::RingProducer,
    stop_flag: Arc<AtomicBool>,
    position: Arc<AtomicU64>,
    delegate: Arc<dyn AudioPlayerDelegate>,
    duration: f64,
    sample_rate: u32,
    channels: u64,
) {
    let mut last_time_update = 0.0_f64;

    while !stop_flag.load(Ordering::Relaxed) {
        let samples = match decoder.decode_next() {
            Some(s) => s,
            None => break, // EOF
        };

        // Write to ring buffer, blocking if full
        let mut offset = 0;
        while offset < samples.len() && !stop_flag.load(Ordering::Relaxed) {
            let written = producer.push_slice(&samples[offset..]);
            if written == 0 {
                // Buffer full — yield and retry
                thread::sleep(std::time::Duration::from_millis(5));
                continue;
            }
            offset += written;
            position.fetch_add(written as u64, Ordering::Relaxed);
        }

        // Periodic time updates (~4 times per second)
        let current = position.load(Ordering::Relaxed) as f64
            / (sample_rate as f64 * channels as f64);
        if (current - last_time_update).abs() >= 0.25 {
            last_time_update = current;
            delegate.on_time_update(current, duration);
        }
    }

    if !stop_flag.load(Ordering::Relaxed) {
        // Natural EOF — wait for ring buffer to drain, then notify
        thread::sleep(std::time::Duration::from_millis(200));
        delegate.on_did_finish_playing();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn volume_clamping() {
        // Test the clamping logic directly
        let vol = 2.5_f32.clamp(0.0, 1.0);
        assert_eq!(vol, 1.0);
        let vol = (-0.5_f32).clamp(0.0, 1.0);
        assert_eq!(vol, 0.0);
        let vol = 0.7_f32.clamp(0.0, 1.0);
        assert_eq!(vol, 0.7);
    }

    #[test]
    fn position_to_time_conversion() {
        let sample_rate: u32 = 44100;
        let channels: u64 = 2;
        let samples: u64 = 44100 * 2 * 3; // 3 seconds
        let time = samples as f64 / (sample_rate as f64 * channels as f64);
        assert!((time - 3.0).abs() < 0.001);
    }
}
