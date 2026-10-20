import 'package:flutter_test/flutter_test.dart';
import 'package:music/core/utils/audio_file_utils.dart';

void main() {
  group('AudioFileUtils - Extension Detection', () {
    test('identifies supported audio formats correctly', () {
      expect(AudioFileUtils.isSupportedAudio('track.mp3'), isTrue);
      expect(AudioFileUtils.isSupportedAudio('audio.flac'), isTrue);
      expect(AudioFileUtils.isSupportedAudio('song.m4a'), isTrue);
      expect(AudioFileUtils.isSupportedAudio('file.wav'), isTrue);
      expect(AudioFileUtils.isSupportedAudio('voice.ogg'), isTrue);
      expect(AudioFileUtils.isSupportedAudio('music.opus'), isTrue);
      expect(AudioFileUtils.isSupportedAudio('track.aac'), isTrue);
      expect(AudioFileUtils.isSupportedAudio('sample.aiff'), isTrue);
    });

    test('handles case-insensitivity in audio extensions', () {
      expect(AudioFileUtils.isSupportedAudio('SONG.MP3'), isTrue);
      expect(AudioFileUtils.isSupportedAudio('Track.FLAC'), isTrue);
      expect(AudioFileUtils.isSupportedAudio('File.Wav'), isTrue);
    });

    test('rejects non-audio formats and empty strings', () {
      expect(AudioFileUtils.isSupportedAudio('image.jpg'), isFalse);
      expect(AudioFileUtils.isSupportedAudio('video.mp4'), isFalse);
      expect(AudioFileUtils.isSupportedAudio('doc.pdf'), isFalse);
      expect(AudioFileUtils.isSupportedAudio('notes.txt'), isFalse);
      expect(AudioFileUtils.isSupportedAudio(''), isFalse);
    });
  });

  group('AudioFileUtils - Format Extraction', () {
    test('extracts uppercase format codec string', () {
      expect(AudioFileUtils.extractFormat('song.mp3'), equals('MP3'));
      expect(AudioFileUtils.extractFormat('track.flac'), equals('FLAC'));
      expect(AudioFileUtils.extractFormat('no_ext'), equals('NO_EXT'));
    });
  });

  group('AudioFileUtils - Duration Formatting', () {
    test('formats null and non-positive durations as --:--', () {
      expect(AudioFileUtils.formatDuration(null), equals('--:--'));
      expect(AudioFileUtils.formatDuration(Duration.zero), equals('--:--'));
      expect(
        AudioFileUtils.formatDuration(const Duration(milliseconds: -100)),
        equals('--:--'),
      );
    });

    test('formats minutes and seconds correctly', () {
      expect(
        AudioFileUtils.formatDuration(const Duration(seconds: 45)),
        equals('0:45'),
      );
      expect(
        AudioFileUtils.formatDuration(const Duration(minutes: 3, seconds: 24)),
        equals('3:24'),
      );
      expect(
        AudioFileUtils.formatDuration(const Duration(minutes: 10, seconds: 5)),
        equals('10:05'),
      );
    });

    test('formats hours, minutes, and seconds correctly', () {
      expect(
        AudioFileUtils.formatDuration(
          const Duration(hours: 1, minutes: 2, seconds: 3),
        ),
        equals('1:02:03'),
      );
    });
  });

  group('AudioFileUtils - Byte Formatting', () {
    test('formats byte numbers cleanly', () {
      expect(AudioFileUtils.formatBytes(0), equals('0 B'));
      expect(AudioFileUtils.formatBytes(512), equals('512.0 B'));
      expect(AudioFileUtils.formatBytes(1024), equals('1.0 KB'));
      expect(AudioFileUtils.formatBytes(5 * 1024 * 1024), equals('5.0 MB'));
      expect(AudioFileUtils.formatBytes(1536 * 1024), equals('1.5 MB'));
    });
  });

  group('AudioFileUtils - Title Extraction Fallback', () {
    test('removes extension and cleans underscores', () {
      expect(
        AudioFileUtils.extractTitleFromFileName('sweet_child_o_mine.mp3'),
        equals('sweet child o mine'),
      );
    });

    test('strips leading track numbering patterns', () {
      expect(
        AudioFileUtils.extractTitleFromFileName('01 - Bohemian Rhapsody.mp3'),
        equals('Bohemian Rhapsody'),
      );
      expect(
        AudioFileUtils.extractTitleFromFileName('02. Stairway to Heaven.flac'),
        equals('Stairway to Heaven'),
      );
      expect(
        AudioFileUtils.extractTitleFromFileName('12_Hotel_California.mp3'),
        equals('Hotel California'),
      );
    });

    test('handles empty or edge case filenames safely', () {
      expect(
        AudioFileUtils.extractTitleFromFileName(''),
        equals('Unknown Title'),
      );
      expect(AudioFileUtils.extractTitleFromFileName('track'), equals('track'));
    });
  });
}
