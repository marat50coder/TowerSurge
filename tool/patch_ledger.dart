import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const List<int> _tideSalt = <int>[
  0xA4, 0x37, 0xF2, 0x8B, 0x51, 0x0C, 0xEE, 0x69,
  0x1D, 0xB5, 0x48, 0xC7, 0x92, 0x3A, 0xDD, 0x66,
];
const int _fnvOffset = 0x811C9DC5;
const int _fnvPrime = 0x01000193;
const int _mask32 = 0xFFFFFFFF;

int _seedFromSalt() {
  int h = _fnvOffset;
  for (int i = 0; i < _tideSalt.length; i++) {
    h ^= _tideSalt[i];
    h = (h * _fnvPrime) & _mask32;
  }
  return h;
}

int _rotl5(int x) {
  x &= _mask32;
  return ((x << 5) | (x >> 27)) & _mask32;
}

List<int> mask(String plain) {
  final Uint8List raw = Uint8List.fromList(utf8.encode(plain));
  final List<int> out = List<int>.filled(raw.length, 0);
  int state = _seedFromSalt();
  for (int i = 0; i < raw.length; i++) {
    state = _rotl5(state);
    state ^= _tideSalt[i % _tideSalt.length];
    state = (state * _fnvPrime) & _mask32;
    out[i] = (raw[i] ^ (state & 0xFF)) & 0xFF;
  }
  return out;
}

String unmask(List<int> hidden) {
  if (hidden.isEmpty) return '';
  final Uint8List raw = Uint8List(hidden.length);
  int state = _seedFromSalt();
  for (int i = 0; i < hidden.length; i++) {
    state = _rotl5(state);
    state ^= _tideSalt[i % _tideSalt.length];
    state = (state * _fnvPrime) & _mask32;
    raw[i] = (hidden[i] ^ (state & 0xFF)) & 0xFF;
  }
  return utf8.decode(raw);
}

String formatArray(String varName, List<int> bytes) {
  final StringBuffer sb = StringBuffer('const List<int> $varName = <int>[\n');
  for (int i = 0; i < bytes.length; i += 8) {
    sb.write('  ');
    for (int j = i; j < i + 8 && j < bytes.length; j++) {
      sb.write('0x${bytes[j].toRadixString(16).toUpperCase().padLeft(2, '0')}');
      if (j < bytes.length - 1) sb.write(',');
      if (j < bytes.length - 1 && j < i + 7) sb.write(' ');
    }
    sb.write('\n');
  }
  sb.write('];');
  return sb.toString();
}

const String kSafeArea = r'''
(function(){
  if (window.__tsPierRim) return;
  window.__tsPierRim = true;
  var STYLE_ID='__ts_rim_style';
  var CSS='.app-header,.gameview-mobile-header,.js-safe-top{padding-top:0!important;margin-top:0!important;}';
  function isKbUp(){
    if(!window.visualViewport)return false;
    return window.visualViewport.height < window.innerHeight * 0.78;
  }
  function paint(){
    if(isKbUp()) return;
    var head=document.head||document.documentElement;
    if(!head) return;
    var meta=document.querySelector('meta[name="viewport"]');
    if(meta){
      var c=(meta.getAttribute('content')||'').replace(/,?\s*viewport-fit\s*=\s*\w+/ig,'').trim();
      meta.setAttribute('content', c + (c?', ':'') + 'viewport-fit=contain');
    }
    var keys=['--safe-area-inset-top','--safe-area-inset-right','--safe-area-inset-bottom','--safe-area-inset-left','--sat','--sar','--sab','--sal','--safe-top','--safe-right','--safe-bottom','--safe-left'];
    for(var i=0;i<keys.length;i++){document.documentElement.style.setProperty(keys[i],'0px','important');}
    var s=document.getElementById(STYLE_ID);
    if(!s){s=document.createElement('style');s.id=STYLE_ID;head.appendChild(s);}
    if(s.textContent!==CSS)s.textContent=CSS;
    if(head.lastElementChild!==s)head.appendChild(s);
  }
  paint();
  ['pushState','replaceState'].forEach(function(fn){
    var orig=history[fn];
    history[fn]=function(){
      var res=orig.apply(this,arguments);
      setTimeout(paint,80);setTimeout(paint,480);
      return res;
    };
  });
  window.addEventListener('popstate',function(){setTimeout(paint,80);});
  setInterval(paint,2500);
})();
''';

const String kKeyboard = r'''
(function(){
  if (window.__tsKbShim) return;
  window.__tsKbShim = true;
  function isInput(el){
    return el && (el.tagName==='INPUT'||el.tagName==='TEXTAREA'||el.isContentEditable);
  }
  function reveal(){
    var el=document.activeElement;
    if(!isInput(el)) return;
    var vp=window.visualViewport;
    if(vp){
      var r=el.getBoundingClientRect();
      var vb=vp.offsetTop+vp.height;
      if(r.bottom>vb-20||r.top<vp.offsetTop){
        try{el.scrollIntoView({behavior:'auto',block:'nearest'});}catch(_){}
      }
    } else {
      try{el.scrollIntoView({behavior:'auto',block:'nearest'});}catch(_){}
    }
  }
  document.addEventListener('focusin',function(e){
    if(isInput(e.target)) setTimeout(reveal,350);
  },true);
  if(window.visualViewport){
    var prevH=window.visualViewport.height;
    window.visualViewport.addEventListener('resize',function(){
      var h=window.visualViewport.height;
      if(h<prevH) setTimeout(reveal,120);
      prevH=h;
    });
  }
})();
''';

void main() {
  final File f = File('lib/tide/mask/masked_ledger.dart');
  String src = f.readAsStringSync();

  final List<int> safeBytes = mask(kSafeArea);
  final List<int> kbBytes = mask(kKeyboard);

  // Verify round-trip
  final String safeBack = unmask(safeBytes);
  final String kbBack = unmask(kbBytes);
  if (safeBack != kSafeArea) throw StateError('safe area round-trip failed');
  if (kbBack != kKeyboard) throw StateError('keyboard round-trip failed');
  print('round-trip ok');

  final String newSafeArea = formatArray('_safeAreaBytes', safeBytes);
  final String newKb = formatArray('_keyboardBytes', kbBytes);

  final RegExp reSafe = RegExp(
    r'const\s+List<int>\s+_safeAreaBytes\s*=\s*<int>\[[\s\S]*?\];',
  );
  final RegExp reKb = RegExp(
    r'const\s+List<int>\s+_keyboardBytes\s*=\s*<int>\[[\s\S]*?\];',
  );

  if (!reSafe.hasMatch(src)) throw StateError('safe area block not found');
  if (!reKb.hasMatch(src)) throw StateError('keyboard block not found');

  src = src.replaceFirst(reSafe, newSafeArea);
  src = src.replaceFirst(reKb, newKb);

  f.writeAsStringSync(src);
  print('patched ${f.path}');
  print('  safe area: ${safeBytes.length} bytes');
  print('  keyboard:  ${kbBytes.length} bytes');
}
