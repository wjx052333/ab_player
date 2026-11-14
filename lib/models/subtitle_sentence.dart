/// 嵌在 MP3 ID3 标签里的一句字幕 (由 data_utils/embed_subtitles.py 写入)
class SubtitleSentence {
  final Duration start;
  final Duration end;
  final String text;

  const SubtitleSentence(this.start, this.end, this.text);
}
