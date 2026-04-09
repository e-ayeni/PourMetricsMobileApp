import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Plays a short till-style beep by synthesising a WAV sine wave in memory.
/// No asset files required.
class BeepPlayer {
  BeepPlayer._();
  static final BeepPlayer instance = BeepPlayer._();

  final AudioPlayer _player = AudioPlayer();

  /// Plays a single scan beep — 880 Hz for 110 ms, with a short fade-out.
  Future<void> playBeep() async {
    final wav = _buildWav(
      frequency: 880,        // A5 — sharp, attention-grabbing
      durationMs: 110,
      sampleRate: 44100,
    );
    await _player.play(BytesSource(wav), volume: 0.9);
  }

  /// Builds a mono 16-bit PCM WAV in memory.
  Uint8List _buildWav({
    required double frequency,
    required int durationMs,
    required int sampleRate,
  }) {
    final numSamples = (sampleRate * durationMs / 1000).round();
    final dataBytes = numSamples * 2; // 16-bit = 2 bytes per sample

    final buf = ByteData(44 + dataBytes);

    // ── RIFF header ────────────────────────────────────────────────────────
    _setAscii(buf, 0, 'RIFF');
    buf.setUint32(4, 36 + dataBytes, Endian.little);
    _setAscii(buf, 8, 'WAVE');

    // ── fmt chunk ──────────────────────────────────────────────────────────
    _setAscii(buf, 12, 'fmt ');
    buf.setUint32(16, 16, Endian.little);           // chunk size
    buf.setUint16(20, 1, Endian.little);            // PCM = 1
    buf.setUint16(22, 1, Endian.little);            // mono
    buf.setUint32(24, sampleRate, Endian.little);
    buf.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    buf.setUint16(32, 2, Endian.little);            // block align
    buf.setUint16(34, 16, Endian.little);           // bits per sample

    // ── data chunk ─────────────────────────────────────────────────────────
    _setAscii(buf, 36, 'data');
    buf.setUint32(40, dataBytes, Endian.little);

    // ── PCM samples — sine wave with 25% fade-out tail ────────────────────
    final fadeStart = (numSamples * 0.75).round();
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final envelope = i < fadeStart
          ? 1.0
          : 1.0 - (i - fadeStart) / (numSamples - fadeStart);
      final raw = (32767 * envelope * sin(2 * pi * frequency * t)).round();
      buf.setInt16(44 + i * 2, raw.clamp(-32768, 32767), Endian.little);
    }

    return buf.buffer.asUint8List();
  }

  void _setAscii(ByteData buf, int offset, String text) {
    for (int i = 0; i < text.length; i++) {
      buf.setUint8(offset + i, text.codeUnitAt(i));
    }
  }
}
