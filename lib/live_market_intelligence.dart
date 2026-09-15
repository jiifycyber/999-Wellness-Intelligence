import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _marketBase = 'https://bridge.sciool.net';

class LiveMarketIntelligencePanel extends StatefulWidget {
  const LiveMarketIntelligencePanel({
    super.key,
    required this.title,
    required this.accent,
  });

  final String title;
  final Color accent;

  @override
  State<LiveMarketIntelligencePanel> createState() =>
      _LiveMarketIntelligencePanelState();
}

class _LiveMarketIntelligencePanelState
    extends State<LiveMarketIntelligencePanel> {
  Timer? _timer;
  final _searchController = TextEditingController();
  bool _loading = true;
  String _status = 'CONNECTING';
  String _filter = 'ALL';
  List<Map<String, dynamic>> _markets = [];

  String get _category {
    final value = widget.title.toUpperCase();
    if (value.contains('CRYPTO')) return 'CRYPTO';
    if (value.contains('FOREX')) return 'FOREX';
    if (value.contains('STOCK')) return 'STOCKS';
    if (value.contains('COMMOD')) return 'COMMODITIES';
    return 'TOP';
  }

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final health = await http
          .get(Uri.parse('$_marketBase/health'))
          .timeout(const Duration(seconds: 10));
      final route = _category == 'TOP'
          ? '$_marketBase/top40'
          : (_category == 'STOCKS' || _category == 'COMMODITIES')
          ? '$_marketBase/symbols'
          : '$_marketBase/category/$_category';
      final response = await http
          .get(Uri.parse(route))
          .timeout(const Duration(seconds: 10));
      if (health.statusCode != 200 || response.statusCode != 200) {
        throw Exception('Market connection failed');
      }
      final healthData = jsonDecode(health.body) as Map<String, dynamic>;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final raw = data['symbols'] as List? ?? [];
      var filtered = raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      if (_category == 'STOCKS') {
        const tokens = ['NAS', 'SPX', 'DJI', 'DAX', 'FTS', 'NIK', 'CAC'];
        filtered = filtered.where((item) {
          final symbol = '${item['symbol'] ?? ''}'.toUpperCase();
          return tokens.any(symbol.contains);
        }).toList();
      } else if (_category == 'COMMODITIES') {
        const tokens = ['XAU', 'XAG', 'XNG', 'XPD', 'XPT', 'USCRUD', 'UKBREN'];
        filtered = filtered.where((item) {
          final symbol = '${item['symbol'] ?? ''}'.toUpperCase();
          return tokens.any(symbol.contains);
        }).toList();
      }

      filtered.sort(
        (a, b) => '${a['symbol'] ?? ''}'.compareTo('${b['symbol'] ?? ''}'),
      );
      if (!mounted) return;
      setState(() {
        _status = '${healthData['market_status'] ?? 'UNKNOWN'}';
        _markets = filtered;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = 'RECONNECTING';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _visibleMarkets {
    final query = _searchController.text.trim().toUpperCase();
    return _markets.where((market) {
      final symbol = '${market['symbol'] ?? ''}'.toUpperCase();
      final isOtc = symbol.endsWith('_OTC');
      final matchesFilter =
          _filter == 'ALL' ||
          (_filter == 'REGULAR' && !isOtc) ||
          (_filter == 'OTC' && isOtc);
      return matchesFilter && (query.isEmpty || symbol.contains(query));
    }).toList();
  }

  String _price(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null) return '--';
    if (number >= 1000) return number.toStringAsFixed(2);
    if (number >= 10) return number.toStringAsFixed(3);
    return number.toStringAsPrecision(6);
  }

  void _openInstrument(Map<String, dynamic> market) {
    final symbol = '${market['symbol'] ?? ''}';
    if (symbol.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MarketInstrumentDetailScreen(
          symbol: symbol,
          category: '${market['category'] ?? _category}',
          initialPrice: market['price'],
          activity: market['activity'],
          accent: widget.accent,
        ),
      ),
    );
  }

  Widget _filterChip(String label) {
    final selected = _filter == label;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = label),
      selectedColor: widget.accent.withValues(alpha: .25),
      backgroundColor: const Color(0xFF0A1733),
      side: BorderSide(
        color: selected
            ? widget.accent
            : const Color(0xFF38507A).withValues(alpha: .65),
      ),
      labelStyle: TextStyle(
        color: selected ? widget.accent : const Color(0xFFAAB7D0),
        fontSize: 9,
        fontWeight: FontWeight.w900,
      ),
      showCheckmark: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final live = _status == 'LIVE';
    final visible = _visibleMarkets;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: const LinearGradient(
          colors: [Color(0xFF0B2047), Color(0xFF0A1733), Color(0xFF120D30)],
        ),
        border: Border.all(color: widget.accent.withValues(alpha: .42)),
        boxShadow: [
          BoxShadow(
            color: widget.accent.withValues(alpha: .10),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.graphic_eq_rounded, color: widget.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _category == 'TOP'
                      ? 'LIVE MARKET FEED'
                      : 'LIVE $_category MARKETS',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${visible.length} PAIRS',
                style: TextStyle(
                  color: widget.accent,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _status,
                style: TextStyle(
                  color: live ? const Color(0xFF59E6A7) : Colors.orange,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
              IconButton(
                onPressed: _refresh,
                tooltip: 'Refresh markets',
                icon: Icon(Icons.refresh_rounded, color: widget.accent),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Search pairs and symbols...',
              hintStyle: const TextStyle(color: Color(0xFF7F90B1)),
              prefixIcon: Icon(Icons.search_rounded, color: widget.accent),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: const Color(0xFF07152E),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: widget.accent.withValues(alpha: .25),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: widget.accent),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            children: [
              _filterChip('ALL'),
              _filterChip('REGULAR'),
              _filterChip('OTC'),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            Center(child: CircularProgressIndicator(color: widget.accent))
          else if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No matching live market pairs.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9DABC4)),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, box) {
                final columns = box.maxWidth >= 950
                    ? 4
                    : box.maxWidth >= 620
                    ? 3
                    : 2;
                final width = (box.maxWidth - ((columns - 1) * 10)) / columns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: visible.map((market) {
                    final symbol = '${market['symbol'] ?? '--'}';
                    final isOtc = symbol.toUpperCase().endsWith('_OTC');
                    final itemLive = market['live'] == true;
                    return SizedBox(
                      width: width,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openInstrument(market),
                          borderRadius: BorderRadius.circular(17),
                          child: Ink(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(17),
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF102653),
                                  widget.accent.withValues(alpha: .12),
                                  const Color(0xFF0A1330),
                                ],
                              ),
                              border: Border.all(
                                color: widget.accent.withValues(alpha: .30),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        symbol,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: itemLive
                                            ? const Color(0xFF59E6A7)
                                            : const Color(0xFFFFB347),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: widget.accent,
                                      size: 17,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _price(market['price']),
                                  style: TextStyle(
                                    color: widget.accent,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            (isOtc
                                                    ? const Color(0xFFFF4DCF)
                                                    : widget.accent)
                                                .withValues(alpha: .12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isOtc ? 'OTC' : 'REGULAR',
                                        style: TextStyle(
                                          color: isOtc
                                              ? const Color(0xFFFF70DB)
                                              : widget.accent,
                                          fontSize: 6.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'ACTIVITY ${market['activity'] ?? 0}',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF8EA0C2),
                                          fontSize: 7,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          const SizedBox(height: 12),
          const Text(
            'Live market information is educational and is not financial advice.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF71809D), fontSize: 8),
          ),
        ],
      ),
    );
  }
}

class MarketInstrumentDetailScreen extends StatefulWidget {
  const MarketInstrumentDetailScreen({
    super.key,
    required this.symbol,
    required this.category,
    required this.initialPrice,
    required this.activity,
    required this.accent,
  });

  final String symbol;
  final String category;
  final dynamic initialPrice;
  final dynamic activity;
  final Color accent;

  @override
  State<MarketInstrumentDetailScreen> createState() =>
      _MarketInstrumentDetailScreenState();
}

class _MarketInstrumentDetailScreenState
    extends State<MarketInstrumentDetailScreen> {
  Timer? _timer;
  Timer? _chartClock;
  bool _loading = true;
  bool _favorite = false;
  String _status = 'CONNECTING';
  String _timeframe = 'M1';
  List<Map<String, dynamic>> _candles = [];

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _refresh());
    _chartClock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _chartClock?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final results = await Future.wait([
        http
            .get(Uri.parse('$_marketBase/health'))
            .timeout(const Duration(seconds: 10)),
        http
            .get(
              Uri.parse(
                '$_marketBase/history/${Uri.encodeComponent(widget.symbol)}',
              ),
            )
            .timeout(const Duration(seconds: 10)),
      ]);
      if (results.any((response) => response.statusCode != 200)) {
        throw Exception('Instrument connection failed');
      }
      final health = jsonDecode(results[0].body) as Map<String, dynamic>;
      final history = jsonDecode(results[1].body) as Map<String, dynamic>;
      final raw = history['candles'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _status = '${health['market_status'] ?? 'UNKNOWN'}';
        _candles = raw
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = 'RECONNECTING';
        _loading = false;
      });
    }
  }

  double? _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value');

  List<Map<String, dynamic>> get _displayCandles {
    final seconds =
        <String, int>{
          'M1': 60,
          'M5': 300,
          'M15': 900,
          'H1': 3600,
        }[_timeframe] ??
        60;
    if (seconds == 60 || _candles.isEmpty) return _candles;

    final groups = <int, List<Map<String, dynamic>>>{};
    for (final candle in _candles) {
      final timestamp = _number(candle['timestamp'])?.toInt();
      if (timestamp == null) continue;
      final bucket = (timestamp ~/ seconds) * seconds;
      groups.putIfAbsent(bucket, () => []).add(candle);
    }

    final buckets = groups.keys.toList()..sort();
    return buckets.map((bucket) {
      final rows = groups[bucket]!;
      rows.sort(
        (a, b) => (_number(a['timestamp']) ?? 0).compareTo(
          _number(b['timestamp']) ?? 0,
        ),
      );
      final highs = rows
          .map((row) => _number(row['high']))
          .whereType<double>()
          .toList();
      final lows = rows
          .map((row) => _number(row['low']))
          .whereType<double>()
          .toList();
      return <String, dynamic>{
        'timestamp': bucket,
        'open': rows.first['open'],
        'high': highs.isEmpty ? rows.first['high'] : highs.reduce(math.max),
        'low': lows.isEmpty ? rows.first['low'] : lows.reduce(math.min),
        'close': rows.last['close'],
      };
    }).toList();
  }

  String _price(dynamic value) {
    final number = _number(value);
    if (number == null) return '--';
    if (number >= 1000) return number.toStringAsFixed(2);
    if (number >= 10) return number.toStringAsFixed(3);
    return number.toStringAsPrecision(6);
  }

  dynamic get _open =>
      _displayCandles.isEmpty ? null : _displayCandles.first['open'];
  dynamic get _high {
    final data = _displayCandles;
    if (data.isEmpty) return null;
    return data
        .map((item) => _number(item['high']))
        .whereType<double>()
        .fold<double>(-double.infinity, math.max);
  }

  dynamic get _low {
    final data = _displayCandles;
    if (data.isEmpty) return null;
    return data
        .map((item) => _number(item['low']))
        .whereType<double>()
        .fold<double>(double.infinity, math.min);
  }

  dynamic get _close => _displayCandles.isEmpty
      ? widget.initialPrice
      : _displayCandles.last['close'];

  Widget _metric(String label, dynamic value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1B3A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: widget.accent.withValues(alpha: .28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8295BA),
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _price(value),
            style: TextStyle(
              color: widget.accent,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final live = _status == 'LIVE';
    return Scaffold(
      backgroundColor: const Color(0xFF050B19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071A3D),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${widget.symbol} Intelligence',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          Center(
            child: Text(
              _status,
              style: TextStyle(
                color: live ? const Color(0xFF59E6A7) : Colors.orange,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () => setState(() => _favorite = !_favorite),
            icon: Icon(
              _favorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: _favorite ? const Color(0xFFFFC44D) : widget.accent,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1250),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0B2047),
                        Color(0xFF0A1733),
                        Color(0xFF171044),
                      ],
                    ),
                    border: Border.all(color: widget.accent),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.symbol,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${widget.category.toUpperCase()} MARKET',
                              style: const TextStyle(
                                color: Color(0xFFA0B0CD),
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _price(_close),
                        style: TextStyle(
                          color: widget.accent,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, box) {
                    final wide = box.maxWidth >= 850;
                    final chart = Container(
                      height: 390,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF07162F),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: widget.accent.withValues(alpha: .48),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.candlestick_chart,
                                color: widget.accent,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'LIVE PRICE LINE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              for (final frame in ['M1', 'M5', 'M15', 'H1'])
                                Padding(
                                  padding: const EdgeInsets.only(left: 5),
                                  child: ChoiceChip(
                                    label: Text(frame),
                                    selected: _timeframe == frame,
                                    onSelected: (_) =>
                                        setState(() => _timeframe = frame),
                                    showCheckmark: false,
                                    selectedColor: widget.accent,
                                    backgroundColor: const Color(0xFF0B2248),
                                    labelStyle: TextStyle(
                                      color: _timeframe == frame
                                          ? const Color(0xFF03101F)
                                          : Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _loading
                                ? Center(
                                    child: CircularProgressIndicator(
                                      color: widget.accent,
                                    ),
                                  )
                                : _candles.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Price history is reconnecting.',
                                      style: TextStyle(
                                        color: Color(0xFF91A3C5),
                                      ),
                                    ),
                                  )
                                : CustomPaint(
                                    painter: _LivePriceLinePainter(
                                      candles: _displayCandles,
                                      accent: widget.accent,
                                      symbol: widget.symbol,
                                      timeframe: _timeframe,
                                      now: DateTime.now(),
                                    ),
                                    child: const SizedBox.expand(),
                                  ),
                          ),
                        ],
                      ),
                    );
                    final metrics = GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: wide ? 1 : 2,
                      childAspectRatio: wide ? 2.7 : 2.0,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      children: [
                        _metric('OPEN', _open),
                        _metric('HIGH', _high),
                        _metric('LOW', _low),
                        _metric('CLOSE', _close),
                      ],
                    );
                    if (!wide) {
                      return Column(
                        children: [chart, const SizedBox(height: 12), metrics],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 4, child: chart),
                        const SizedBox(width: 12),
                        SizedBox(width: 220, child: metrics),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _infoCard(
                      icon: Icons.equalizer_rounded,
                      label: 'MARKET ACTIVITY',
                      value: '${widget.activity ?? 0}',
                    ),
                    _infoCard(
                      icon: Icons.history_toggle_off_rounded,
                      label: 'DATA POINTS',
                      value: '${_displayCandles.length}',
                    ),
                    _infoCard(
                      icon: Icons.public_rounded,
                      label: 'CONNECTION',
                      value: _status,
                    ),
                    _infoCard(
                      icon: Icons.star_outline_rounded,
                      label: 'WATCHLIST',
                      value: _favorite ? 'SAVED' : 'ADD',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Live market information is educational and is not financial advice.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF71809D), fontSize: 8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        gradient: const LinearGradient(
          colors: [Color(0xFF102653), Color(0xFF0A1330)],
        ),
        border: Border.all(color: widget.accent.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: widget.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF8799BA),
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LivePriceLinePainter extends CustomPainter {
  const _LivePriceLinePainter({
    required this.candles,
    required this.accent,
    required this.symbol,
    required this.timeframe,
    required this.now,
  });

  final List<Map<String, dynamic>> candles;
  final Color accent;
  final String symbol;
  final String timeframe;
  final DateTime now;

  double? _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value');

  int get _frameSeconds =>
      const {'M1': 60, 'M5': 300, 'M15': 900, 'H1': 3600}[timeframe] ?? 60;

  String _price(double value) {
    if (symbol.toUpperCase().contains('JPY')) {
      return value.toStringAsFixed(3);
    }
    if (value >= 1000) return value.toStringAsFixed(2);
    if (value >= 10) return value.toStringAsFixed(3);
    if (value >= 1) return value.toStringAsFixed(5);
    return value.toStringAsFixed(6);
  }

  String _time(dynamic value) {
    var timestamp = _number(value)?.toInt();
    if (timestamp == null) return '--:--';
    if (timestamp > 9999999999) timestamp ~/= 1000;

    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)
        .toLocal();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  TextPainter _text(
    String value, {
    Color color = const Color(0xFF91A8CE),
    double size = 8,
    FontWeight weight = FontWeight.w600,
  }) {
    return TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(color: color, fontSize: size, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final shown = candles.length > 60
        ? candles.sublist(candles.length - 60)
        : candles;

    final valid = shown
        .where((item) => _number(item['close']) != null)
        .toList();

    if (valid.length < 2) return;

    final closes = valid.map((item) => _number(item['close'])!).toList();

    final rawHigh = closes.reduce(math.max);
    final rawLow = closes.reduce(math.min);
    final rawRange = math.max(
      rawHigh - rawLow,
      math.max(rawHigh.abs(), 1) * .00001,
    );

    final chartHigh = rawHigh + rawRange * .10;
    final chartLow = rawLow - rawRange * .10;
    final chartRange = chartHigh - chartLow;

    const left = 4.0;
    const top = 18.0;
    const rightAxis = 72.0;
    const bottomAxis = 30.0;

    final width = math.max(1.0, size.width - left - rightAxis);
    final height = math.max(1.0, size.height - top - bottomAxis);
    final chartRect = Rect.fromLTWH(left, top, width, height);

    final gridPaint = Paint()
      ..color = const Color(0xFF31517F).withValues(alpha: .35)
      ..strokeWidth = 1;

    for (var i = 0; i <= 5; i++) {
      final y = top + height * i / 5;

      canvas.drawLine(Offset(left, y), Offset(left + width, y), gridPaint);

      final label = _text(_price(chartHigh - chartRange * i / 5));
      label.paint(canvas, Offset(left + width + 7, y - label.height / 2));
    }

    for (var i = 0; i <= 5; i++) {
      final x = left + width * i / 5;
      canvas.drawLine(Offset(x, top), Offset(x, top + height), gridPaint);
    }

    double xFor(int index) => left + width * index / (closes.length - 1);

    double yFor(double value) =>
        top + (1 - ((value - chartLow) / chartRange)) * height;

    final points = <Offset>[
      for (var i = 0; i < closes.length; i++) Offset(xFor(i), yFor(closes[i])),
    ];

    final line = Path()..moveTo(points.first.dx, points.first.dy);

    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final middle = (previous.dx + current.dx) / 2;

      line.cubicTo(
        middle,
        previous.dy,
        middle,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final fill = Path.from(line)
      ..lineTo(points.last.dx, top + height)
      ..lineTo(points.first.dx, top + height)
      ..close();

    canvas.save();
    canvas.clipRect(chartRect);

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: .34),
            accent.withValues(alpha: .08),
            accent.withValues(alpha: 0),
          ],
        ).createShader(chartRect),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = accent.withValues(alpha: .25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.restore();

    final last = points.last;
    final currentPrice = closes.last;

    canvas.drawLine(
      Offset(left, last.dy),
      Offset(left + width, last.dy),
      Paint()
        ..color = accent.withValues(alpha: .55)
        ..strokeWidth = 1,
    );

    canvas.drawCircle(last, 10, Paint()..color = accent.withValues(alpha: .22));
    canvas.drawCircle(last, 5, Paint()..color = accent);
    canvas.drawCircle(last, 2.2, Paint()..color = Colors.white);

    final priceLabel = _text(
      _price(currentPrice),
      color: const Color(0xFF03101F),
      size: 9,
      weight: FontWeight.w900,
    );

    final priceBox = RRect.fromRectAndRadius(
      Rect.fromLTWH(left + width + 2, last.dy - 12, rightAxis - 3, 24),
      const Radius.circular(7),
    );

    canvas.drawRRect(priceBox, Paint()..color = accent);

    priceLabel.paint(
      canvas,
      Offset(
        left + width + (rightAxis - priceLabel.width) / 2,
        last.dy - priceLabel.height / 2,
      ),
    );

    final elapsed = (now.millisecondsSinceEpoch ~/ 1000) % _frameSeconds;
    final remaining = _frameSeconds - elapsed;
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;

    final countdownText =
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';

    final countdown = _text(
      countdownText,
      color: Colors.white,
      size: 9,
      weight: FontWeight.w800,
    );

    final countdownWidth = countdown.width + 18;
    final countdownLeft = left + width - countdownWidth;

    final countdownBox = RRect.fromRectAndRadius(
      Rect.fromLTWH(countdownLeft, top + 7, countdownWidth, 25),
      const Radius.circular(8),
    );

    canvas.drawRRect(countdownBox, Paint()..color = const Color(0xFF102653));

    canvas.drawRRect(
      countdownBox,
      Paint()
        ..color = accent.withValues(alpha: .55)
        ..style = PaintingStyle.stroke,
    );

    countdown.paint(
      canvas,
      Offset(countdownLeft + 9, top + 7 + (25 - countdown.height) / 2),
    );

    final indexes = <int>{
      0,
      (valid.length - 1) ~/ 4,
      (valid.length - 1) ~/ 2,
      ((valid.length - 1) * 3) ~/ 4,
      valid.length - 1,
    }.toList()..sort();

    for (final index in indexes) {
      final label = _text(_time(valid[index]['timestamp']));
      final rawX = xFor(index) - label.width / 2;
      final x = rawX.clamp(left, left + width - label.width);

      label.paint(canvas, Offset(x.toDouble(), top + height + 9));
    }
  }

  @override
  bool shouldRepaint(covariant _LivePriceLinePainter oldDelegate) =>
      oldDelegate.candles != candles ||
      oldDelegate.accent != accent ||
      oldDelegate.symbol != symbol ||
      oldDelegate.timeframe != timeframe ||
      oldDelegate.now.second != now.second;
}
