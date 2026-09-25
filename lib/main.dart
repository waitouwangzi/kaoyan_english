import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:just_audio/just_audio.dart';

void main() {
  runApp(const WordMapApp());
}

class WordMapApp extends StatelessWidget {
  const WordMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '词汇导图',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      ),
      home: const HomePage(),
    );
  }
}

// ─────────────────────────────── 数据模型 ───────────────────────────────

class WordData {
  final String word;
  final String phoneticUk;
  final String phoneticUs;
  final String pos;
  final String meaning;
  String color; // 用 var 而非 final，允许后面赋值

  WordData({
    required this.word,
    required this.phoneticUk,
    required this.phoneticUs,
    required this.pos,
    required this.meaning,
    required this.color,
  });

  factory WordData.fromJson(Map<String, dynamic> json) {
    return WordData(
      word: json['word'] as String,
      phoneticUk: json['phonetic_uk'] as String,
      phoneticUs: json['phonetic_us'] as String,
      pos: json['pos'] as String,
      meaning: json['meaning'] as String,
      color: json['color'] as String? ?? wordToColor(json['word'] as String),
    );
  }
}

class WordFamily {
  final String root;
  final List<WordData> members;

  WordFamily({required this.root, required this.members});
}

// ─────────────────────────────── 词族分组 ───────────────────────────────

List<WordFamily> buildWordFamilies(List<WordData> allWords) {
  final Map<String, List<WordData>> families = {};
  final Set<String> assigned = {};

  for (final word in allWords) {
    final base = extractBase(word.word);
    if (!assigned.contains(word.word)) {
      assigned.add(word.word);
      families.putIfAbsent(base, () => []).add(word);
    }
  }

  return families.entries
      .map((e) => WordFamily(root: e.key, members: e.value))
      .where((f) => f.members.isNotEmpty)
      .toList()
    ..sort((a, b) => b.members.length.compareTo(a.members.length));
}

/// 提取词根：去掉常见前缀后缀后的核心部分
String extractBase(String word) {
  final w = word.toLowerCase().replaceAll(RegExp(r"['\-]"), '');

  // 常见后缀
  final suffixes = [
    'tion', 'sion', 'ment', 'ness', 'able', 'ible', 'ful', 'less',
    'ous', 'ive', 'al', 'ic', 'ly', 'ed', 'ing', 'er', 'or',
    'ity', 'ize', 'ise', 'ance', 'ence', 'logy', 'graphy',
    'phy', 'hood', 'ship', 'dom', 'ware', 'work',
  ];
  for (final s in suffixes) {
    if (w.length > s.length + 2 && w.endsWith(s)) {
      final candidate = w.substring(0, w.length - s.length);
      if (candidate.length >= 2) return candidate;
    }
  }

  // 常见前缀
  final prefixes = [
    'un', 're', 'pre', 'dis', 'mis', 'over', 'under', 'out',
    'up', 'down', 'into', 'upon', 'between', 'across',
  ];
  for (final p in prefixes) {
    if (w.length > p.length + 2 && w.startsWith(p)) {
      final candidate = w.substring(p.length);
      if (candidate.length >= 2) return candidate;
    }
  }

  return w;
}

// ─────────────────────────────── 颜色工具 ───────────────────────────────

String wordToColor(String word) {
  int h = word.runes.fold(0, (p, r) => p + r) % 360;
  int s = (word.runes.fold(0, (p, r) => p + r * 3) % 40) + 40; // 40-80
  int l = (word.runes.fold(0, (p, r) => p + r * 7) % 20) + 55; // 55-75
  return 'hsl($h, $s%, $l%)';
}

Color hslColor(String hsl) {
  final match = RegExp(r'hsl\((\d+),\s*(\d+)%,\s*(\d+)%\)').firstMatch(hsl);
  if (match != null) {
    final hh = double.tryParse(match.group(1)!) ?? 0;
    final ss = double.tryParse(match.group(2)!) ?? 50;
    final ll = double.tryParse(match.group(3)!) ?? 60;
    return HSLColor.fromAHSL(1.0, hh, ss / 100.0, ll / 100.0).toColor();
  }
  return Colors.blue;
}

LinearGradient hslGradient(String hsl) {
  final c = hslColor(hsl);
  return LinearGradient(
    colors: [c, c.withValues(alpha: 0.7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─────────────────────────────── 主页 ───────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<WordData> allWords = [];
  List<WordFamily> families = [];
  String searchQuery = '';
  AudioPlayer? _audioPlayer;
  String? _playingWord;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final str = await rootBundle.loadString('assets/word_data.json');
      final map = json.decode(str) as Map<String, dynamic>;
      final List<dynamic> wordsJson = map['words'] as List<dynamic>;

      allWords = wordsJson
          .map((e) => WordData.fromJson(e as Map<String, dynamic>))
          .toList();

      families = buildWordFamilies(allWords);
      setState(() {});
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
  }

  Future<void> playAudio(String word) async {
    _audioPlayer = AudioPlayer();
    if (_playingWord == word) {
      await _audioPlayer!.stop();
      setState(() => _playingWord = null);
      return;
    }
    try {
      // 生成文件名：转为小写，非字母数字替换为下划线
      final safeName = word.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
      await _audioPlayer!.setAsset('assets/audio/${safeName}_en.mp3');
      await _audioPlayer!.play();
      setState(() => _playingWord = word);
    } catch (e) {
      debugPrint('Audio error for $word: $e');
      // 尝试备用格式
      try {
        final altName = word.toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9\-]'), '-')
            .replaceAll(RegExp(r'-+'), '-')
            .replaceAll(RegExp(r'^-|-$'), '');
        await _audioPlayer!.setAsset('assets/audio/${altName}_en.mp3');
        await _audioPlayer!.play();
        setState(() => _playingWord = word);
      } catch (e2) {
        debugPrint('Audio fallback failed: $e2');
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  List<WordData> get filteredWords {
    if (searchQuery.isEmpty) return allWords;
    final q = searchQuery.toLowerCase();
    return allWords.where((w) => w.word.toLowerCase().contains(q)).toList();
  }

  List<WordFamily> get filteredFamilies {
    if (searchQuery.isEmpty) return families;
    final q = searchQuery.toLowerCase();
    return families
        .where((f) => f.root.toLowerCase().contains(q) ||
            f.members.any((m) => m.word.toLowerCase().contains(q)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('词汇导图', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blue.shade600,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAboutDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: (v) => setState(() => searchQuery = v),
              decoration: InputDecoration(
                hintText: '搜索单词，如: water, action...',
                prefixIcon: const Icon(Icons.search, color: Colors.blue),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => searchQuery = ''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          // 统计信息
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statChip('总词汇', '${allWords.length}'),
                _statChip('词族数', '${families.length}'),
                _statChip('当前', '${filteredWords.length}'),
              ],
            ),
          ),
          const Divider(height: 1),
          // 内容区域
          Expanded(
            child: filteredWords.isEmpty
                ? const Center(child: Text('没有找到匹配的单词', style: TextStyle(color: Colors.grey)))
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $value', style: const TextStyle(fontSize: 12, color: Colors.blue)),
    );
  }

  Widget _buildContent() {
    if (searchQuery.isEmpty) {
      return _buildFamilyView();
    }
    return _buildSearchView();
  }

  Widget _buildFamilyView() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filteredFamilies.length,
      itemBuilder: (context, index) {
        final family = filteredFamilies[index];
        return _FamilyCard(
          root: family.root,
          members: family.members,
          isPlaying: _playingWord,
          onPlay: playAudio,
        );
      },
    );
  }

  Widget _buildSearchView() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filteredWords.length,
      itemBuilder: (context, index) {
        final word = filteredWords[index];
        return _WordSearchCard(
          word: word,
          isPlaying: _playingWord == word.word,
          onPlay: () => playAudio(word.word),
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('关于词汇导图'),
        content: Text('离线版考研英语词汇学习工具\n支持词族思维导图浏览\n点击节点可播放发音\n共收录 ${allWords.length} 个考研核心词汇'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('确定')),
        ],
      ),
    );
  }
}

// ─────────────────────────────── 词族卡片（思维导图形式） ───────────────────────────────

class _FamilyCard extends StatefulWidget {
  final String root;
  final List<WordData> members;
  final String? isPlaying;
  final Function(String) onPlay;

  const _FamilyCard({
    required this.root,
    required this.members,
    required this.isPlaying,
    required this.onPlay,
  });

  @override
  State<_FamilyCard> createState() => _FamilyCardState();
}

class _FamilyCardState extends State<_FamilyCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _RootNode(word: widget.root, color: widget.members.firstOrNull?.color ?? 'hsl(210,60%,60%)'),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.root,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.members.length} 个相关词汇',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: _buildCollapsedPreview(),
            secondChild: _buildExpandedMembers(),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedPreview() {
    final preview = widget.members.take(3).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: preview.map((w) => _WordChip(word: w.word, color: w.color)).toList(),
      ),
    );
  }

  Widget _buildExpandedMembers() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
      ),
      child: Column(
        children: widget.members
            .map((w) => _MemberRow(word: w, isPlaying: widget.isPlaying == w.word, onPlay: widget.onPlay))
            .toList(),
      ),
    );
  }
}

class _RootNode extends StatelessWidget {
  final String word;
  final String color;
  const _RootNode({required this.word, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hslGradient(color),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Center(
        child: Text(
          word.substring(0, word.length.clamp(0, 4)),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  final String word;
  final String color;
  const _WordChip({required this.word, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hslColor(color).withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: hslColor(color).withValues(alpha: 0.1), blurRadius: 4)],
      ),
      child: Text(word, style: TextStyle(fontSize: 13, color: hslColor(color))),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final WordData word;
  final bool isPlaying;
  final Function(String) onPlay;

  const _MemberRow({required this.word, required this.isPlaying, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onPlay(word.word),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: hslColor(word.color)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(word.word, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(4)),
                        child: Text(word.pos, style: TextStyle(fontSize: 11, color: Colors.blue.shade700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${word.phoneticUk}  ${word.phoneticUs}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                word.meaning,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => onPlay(word.word),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPlaying ? Colors.blue.shade600 : Colors.grey.shade200,
                ),
                child: Icon(
                  isPlaying ? Icons.stop : Icons.play_arrow,
                  size: 20,
                  color: isPlaying ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────── 搜索卡片 ───────────────────────────────

class _WordSearchCard extends StatelessWidget {
  final WordData word;
  final bool isPlaying;
  final VoidCallback onPlay;

  const _WordSearchCard({required this.word, required this.isPlaying, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: hslGradient(word.color)),
          child: Center(
            child: Text(
              word.word.substring(0, word.word.length.clamp(0, 2)),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(word.word, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(4)),
              child: Text(word.pos, style: TextStyle(fontSize: 11, color: Colors.blue.shade700)),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${word.phoneticUk}  ${word.phoneticUs}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 2),
            Text(word.meaning, style: const TextStyle(fontSize: 14)),
          ],
        ),
        trailing: GestureDetector(
          onTap: onPlay,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: isPlaying ? Colors.blue.shade600 : Colors.grey.shade200),
            child: Icon(
              isPlaying ? Icons.stop : Icons.play_arrow,
              size: 22,
              color: isPlaying ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}
