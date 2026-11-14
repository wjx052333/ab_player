// Ogg/Speex -> 16-bit PCM 解码封装 (libspeex, BSD)，供 Dart FFI 调用。
// Android 的 ExoPlayer / MediaPlayer 都不支持 Speex，而 Sound_us_uk.mdd 里的发音全是 Ogg/Speex。
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <speex/speex.h>
#include <speex/speex_header.h>
#include <speex/speex_stereo.h>

#define SPX_API __attribute__((visibility("default")))

typedef struct {
  const uint8_t* data;
  int len;
  int pos;
  uint8_t* pkt;      // 正在拼装的 packet (跨 segment / 跨 page)
  int pkt_len;
  int pkt_cap;
} OggReader;

static int append(OggReader* r, const uint8_t* p, int n) {
  if (r->pkt_len + n > r->pkt_cap) {
    int cap = (r->pkt_len + n) * 2 + 256;
    uint8_t* np = (uint8_t*)realloc(r->pkt, cap);
    if (!np) return 0;
    r->pkt = np;
    r->pkt_cap = cap;
  }
  memcpy(r->pkt + r->pkt_len, p, n);
  r->pkt_len += n;
  return 1;
}

// 读下一个完整 packet；返回 1 成功，0 结束/出错。packet 内容在 r->pkt / r->pkt_len。
static int next_packet(OggReader* r, int* seg_idx, int* seg_cnt, uint8_t seg_table[255], int* page_body) {
  r->pkt_len = 0;
  for (;;) {
    if (*seg_idx >= *seg_cnt) {
      // 读下一页头
      if (r->pos + 27 > r->len || memcmp(r->data + r->pos, "OggS", 4) != 0) return 0;
      int n = r->data[r->pos + 26];
      if (r->pos + 27 + n > r->len) return 0;
      memcpy(seg_table, r->data + r->pos + 27, n);
      *seg_cnt = n;
      *seg_idx = 0;
      *page_body = r->pos + 27 + n;
      r->pos = *page_body;
      continue;
    }
    int sz = seg_table[*seg_idx];
    if (r->pos + sz > r->len) return 0;
    if (!append(r, r->data + r->pos, sz)) return 0;
    r->pos += sz;
    (*seg_idx)++;
    if (sz < 255) return 1;
  }
}

// 解码整段 Ogg/Speex 数据。成功返回采样数 (mono int16)，*out_pcm 由 spx_free_pcm 释放；失败返回 <=0。
SPX_API int spx_decode_ogg(const uint8_t* data, int len, int16_t** out_pcm, int* out_rate) {
  OggReader r = {data, len, 0, NULL, 0, 0};
  uint8_t seg_table[255];
  int seg_idx = 0, seg_cnt = 0, page_body = 0;
  int ret = -1;
  void* st = NULL;
  SpeexBits bits;
  int16_t* pcm = NULL;
  int pcm_len = 0, pcm_cap = 0;
  int frame_size = 0, frames_per_packet = 1, channels = 1, rate = 0;
  int pkt_index = 0;

  speex_bits_init(&bits);
  *out_pcm = NULL;
  *out_rate = 0;

  while (next_packet(&r, &seg_idx, &seg_cnt, seg_table, &page_body)) {
    if (pkt_index == 0) {
      SpeexHeader* h = speex_packet_to_header((char*)r.pkt, r.pkt_len);
      if (!h) goto done;
      const SpeexMode* mode = speex_lib_get_mode(h->mode);
      if (!mode) { free(h); goto done; }
      st = speex_decoder_init(mode);
      if (!st) { free(h); goto done; }
      int enh = 1;
      speex_decoder_ctl(st, SPEEX_SET_ENH, &enh);
      speex_decoder_ctl(st, SPEEX_GET_FRAME_SIZE, &frame_size);
      rate = h->rate;
      frames_per_packet = h->frames_per_packet > 0 ? h->frames_per_packet : 1;
      channels = h->nb_channels > 0 ? h->nb_channels : 1;
      free(h);
      if (frame_size <= 0 || channels != 1) goto done;
    } else if (pkt_index >= 2) {
      speex_bits_read_from(&bits, (char*)r.pkt, r.pkt_len);
      for (int i = 0; i < frames_per_packet; i++) {
        if (pcm_len + frame_size > pcm_cap) {
          int cap = pcm_cap ? pcm_cap * 2 : 16384;
          while (cap < pcm_len + frame_size) cap *= 2;
          int16_t* np = (int16_t*)realloc(pcm, (size_t)cap * sizeof(int16_t));
          if (!np) goto done;
          pcm = np;
          pcm_cap = cap;
        }
        int rc = speex_decode_int(st, &bits, pcm + pcm_len);
        if (rc != 0) break;  // -1 流结束, -2 损坏
        pcm_len += frame_size;
      }
    }
    pkt_index++;
  }
  if (pcm_len > 0) {
    *out_pcm = pcm;
    *out_rate = rate;
    pcm = NULL;
    ret = pcm_len;
  }

done:
  if (st) speex_decoder_destroy(st);
  speex_bits_destroy(&bits);
  free(r.pkt);
  free(pcm);
  return ret;
}

SPX_API void spx_free_pcm(int16_t* pcm) { free(pcm); }
