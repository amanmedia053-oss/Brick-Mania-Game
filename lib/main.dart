import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const BrickManiaApp());
}

const Color bg = Color(0xFF07111F);
const Color neon = Color(0xFF45F0B5);

class BrickManiaApp extends StatelessWidget {
  const BrickManiaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'د خښتو لوبه',
    theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: bg, colorScheme: const ColorScheme.dark(primary: neon)),
    home: const GameScreen(),
  );
}

class Brick {
  Brick(this.rect, this.hp, this.color);
  Rect rect;
  int hp;
  Color color;
}

class Reward {
  Reward(this.x, this.y, this.kind);
  double x;
  double y;
  int kind; // 0 wide paddle, 1 extra life, 2 slow ball, 3 bonus points
}

class Ball {
  Ball(this.x, this.y, this.vx, this.vy);
  double x, y, vx, vy;
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final Random random = Random();
  final List<Brick> bricks = [];
  final List<Reward> rewards = [];
  final List<Ball> balls = [];
  Timer? ticker;
  Size board = Size.zero;
  double paddleX = 0;
  double paddleWidth = 92;
  double ballRadius = 7;
  int score = 0, best = 0, lives = 3, level = 1;
  int tickCount = 0;
  bool running = false, started = false, gameOver = false;
  bool shield = false, slow = false;
  String notice = 'د لوبې پیل لپاره تڼۍ کېکاږئ';

  @override
  void initState() {
    super.initState();
    _loadBest();
  }

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => best = prefs.getInt('best_score') ?? 0);
  }

  void _saveBest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('best_score', best);
  }

  void _makeLevel() {
    bricks.clear();
    rewards.clear();
    balls.clear();
    paddleWidth = 92;
    shield = false;
    slow = false;
    final cols = 7;
    final rows = min(4 + level ~/ 2, 8);
    const gap = 5.0;
    final brickW = (board.width - 28 - gap * (cols - 1)) / cols;
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        if (level >= 3 && (row + col + level) % 11 == 0) continue;
        final left = 14 + col * (brickW + gap);
        final top = 72.0 + row * 27.0;
        final hp = 1 + ((level >= 3 && row < level % 3) ? 1 : 0) + (level >= 7 && (row + col) % 5 == 0 ? 1 : 0);
        final colors = [const Color(0xFF35D6C5), const Color(0xFF5D9CFF), const Color(0xFFB18CFF), const Color(0xFFFFB454), const Color(0xFFFF6E91)];
        bricks.add(Brick(Rect.fromLTWH(left, top, brickW, 19), hp, colors[(row + col + level) % colors.length]));
      }
    }
    paddleX = board.width / 2;
    balls.add(Ball(board.width / 2, board.height - 72, 2.8 + level * 0.12, -(4.0 + level * 0.08)));
  }

  void _start() {
    if (board == Size.zero) return;
    if (gameOver) {
      score = 0;
      lives = 3;
      level = 1;
      gameOver = false;
    }
    if (!started || bricks.isEmpty) _makeLevel();
    started = true;
    running = true;
    notice = '';
    ticker?.cancel();
    ticker = Timer.periodic(const Duration(milliseconds: 16), (_) => _step());
    setState(() {});
  }

  void _step() {
    if (!mounted || !running || board == Size.zero) return;
    tickCount++;
    final speedFactor = slow ? 0.72 : 1.0;
    final paddle = Rect.fromCenter(center: Offset(paddleX, board.height - 35), width: paddleWidth, height: 13);
    for (final ball in balls) {
      ball.x += ball.vx * speedFactor;
      ball.y += ball.vy * speedFactor;
      if (ball.x < ballRadius || ball.x > board.width - ballRadius) ball.vx = -ball.vx;
      if (ball.y < ballRadius + 45) ball.vy = ball.vy.abs();
      final ballRect = Rect.fromCircle(center: Offset(ball.x, ball.y), radius: ballRadius);
      if (ball.vy > 0 && ballRect.overlaps(paddle)) {
        final hit = (ball.x - paddleX) / (paddleWidth / 2);
        ball.vx = hit * 4.2;
        ball.vy = -ball.vy.abs();
        ball.y = paddle.top - ballRadius - 1;
      }
      for (int i = bricks.length - 1; i >= 0; i--) {
        final brick = bricks[i];
        if (ballRect.overlaps(brick.rect)) {
          brick.hp--;
          ball.vy = -ball.vy;
          if (brick.hp <= 0) {
            final center = brick.rect.center;
            score += 10 * level;
            if (random.nextInt(100) < 22) rewards.add(Reward(center.dx, center.dy, random.nextInt(4)));
            bricks.removeAt(i);
          } else {
            score += 3;
          }
          if (score > best) { best = score; _saveBest(); }
          break;
        }
      }
    }
    for (int i = rewards.length - 1; i >= 0; i--) {
      final r = rewards[i];
      r.y += 2.5;
      if (r.y > board.height - 45 && r.y < board.height - 20 && (r.x - paddleX).abs() < paddleWidth / 2 + 12) {
        if (r.kind == 0) { paddleWidth = 138; notice = 'لوی راکټ!'; }
        if (r.kind == 1) { lives = min(5, lives + 1); notice = 'اضافي ژوند!'; }
        if (r.kind == 2) { slow = true; notice = 'توپ ورو شو!'; }
        if (r.kind == 3) { score += 100; notice = '۱۰۰ اضافي نمرې!'; }
        rewards.removeAt(i);
      } else if (r.y > board.height) {
        rewards.removeAt(i);
      }
    }
    balls.removeWhere((b) => b.y > board.height + 20);
    if (balls.isEmpty) {
      lives--;
      if (lives <= 0) {
        running = false;
        gameOver = true;
        notice = 'لوبه پای ته ورسېده';
        ticker?.cancel();
      } else {
        balls.add(Ball(paddleX, board.height - 72, 2.8, -4.2));
        notice = 'یو ژوند پاتې شو: ' + lives.toString();
      }
    }
    if (bricks.isEmpty && !gameOver) {
      running = false;
      level++;
      notice = 'بریا! بل پړاو: ' + level.toString();
      ticker?.cancel();
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted && !gameOver) { _makeLevel(); _start(); }
      });
    }
    if (tickCount % 3 == 0 && mounted) setState(() {});
  }

  void _movePaddle(Offset local) {
    if (board == Size.zero) return;
    setState(() => paddleX = local.dx.clamp(paddleWidth / 2 + 4, board.width - paddleWidth / 2 - 4));
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: Row(children: [
              const Icon(Icons.sports_esports, color: neon, size: 28),
              const SizedBox(width: 9),
              const Expanded(child: Text('د خښتو اتل', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold))),
              _stat('نمرې', score.toString()),
              const SizedBox(width: 8),
              _stat('ژوند', lives.toString()),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('پړاو: $level', style: const TextStyle(color: Colors.white70)),
              Text('ریکارډ: $best', style: const TextStyle(color: neon, fontWeight: FontWeight.bold)),
            ]),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final newSize = Size(constraints.maxWidth, constraints.maxHeight);
              if (board != newSize) {
                board = newSize;
                if (!started) { paddleX = board.width / 2; }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && started && balls.isEmpty && !gameOver) _makeLevel();
                });
              }
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) => _movePaddle(d.localPosition),
                onTapDown: (d) { if (!running) _start(); else _movePaddle(d.localPosition); },
                child: CustomPaint(
                  size: Size.infinite,
                  painter: BoardPainter(bricks: bricks, rewards: rewards, balls: balls, paddleX: paddleX,
                    paddleWidth: paddleWidth, lives: lives, level: level, running: running, notice: notice,
                    gameOver: gameOver, started: started),
                ),
              );
            }),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            child: Row(children: [
              Expanded(child: Text('راکټ د ګوتې په خوځولو کنټرول کړئ', style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 12))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: neon, foregroundColor: bg, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
                onPressed: running ? () { setState(() { running = false; ticker?.cancel(); notice = 'لوبه درول شوې'; }); } : _start,
                icon: Icon(running ? Icons.pause : Icons.play_arrow),
                label: Text(running ? 'تم' : (gameOver ? 'بیا پیل' : 'پیل')),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _stat(String title, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(color: const Color(0xFF14263A), borderRadius: BorderRadius.circular(12)),
    child: Column(children: [Text(title, style: const TextStyle(fontSize: 10, color: Colors.white60)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: neon))]),
  );
}

class BoardPainter extends CustomPainter {
  BoardPainter({required this.bricks, required this.rewards, required this.balls, required this.paddleX,
    required this.paddleWidth, required this.lives, required this.level, required this.running,
    required this.notice, required this.gameOver, required this.started});
  final List<Brick> bricks;
  final List<Reward> rewards;
  final List<Ball> balls;
  final double paddleX, paddleWidth;
  final int lives, level;
  final bool running, gameOver, started;
  final String notice;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..shader = const LinearGradient(colors: [Color(0xFF0B1B2D), Color(0xFF07111F)], begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);
    final grid = Paint()..color = Colors.white.withOpacity(.035)..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 28) canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    for (double y = 0; y < size.height; y += 28) canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    final glow = Paint()..color = const Color(0xFF45F0B5).withOpacity(.18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    for (final b in bricks) {
      canvas.drawRRect(RRect.fromRectAndRadius(b.rect.inflate(2), const Radius.circular(6)), glow);
      final p = Paint()..color = b.color;
      canvas.drawRRect(RRect.fromRectAndRadius(b.rect, const Radius.circular(5)), p);
      if (b.hp > 1) {
        final tp = TextPainter(text: TextSpan(text: b.hp.toString(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, b.rect.center - Offset(tp.width / 2, tp.height / 2));
      }
    }
    for (final r in rewards) {
      final colors = [const Color(0xFF45F0B5), const Color(0xFFFFC857), const Color(0xFF65B7FF), const Color(0xFFB18CFF)];
      final p = Paint()..color = colors[r.kind];
      canvas.drawCircle(Offset(r.x, r.y), 9, p);
      final label = ['W', '+', 'S', '★'][r.kind];
      final tp = TextPainter(text: TextSpan(text: label, style: const TextStyle(color: bg, fontSize: 11, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(r.x - tp.width / 2, r.y - tp.height / 2));
    }
    final paddleRect = Rect.fromCenter(center: Offset(paddleX, size.height - 35), width: paddleWidth, height: 13);
    canvas.drawRRect(RRect.fromRectAndRadius(paddleRect.inflate(5), const Radius.circular(12)), Paint()..color = const Color(0xFF45F0B5).withOpacity(.22)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
    canvas.drawRRect(RRect.fromRectAndRadius(paddleRect, const Radius.circular(8)), Paint()..shader = const LinearGradient(colors: [Color(0xFF45F0B5), Color(0xFF1BAA9A)]).createShader(paddleRect));
    for (final b in balls) {
      canvas.drawCircle(Offset(b.x, b.y), 7, Paint()..color = Colors.white.withOpacity(.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.drawCircle(Offset(b.x, b.y), 6, Paint()..color = Colors.white);
    }
    if (!running) {
      final title = gameOver ? 'لوبه پای ته ورسېده' : (started ? notice : 'د خښتو اتل');
      final sub = gameOver ? 'د بیا پیل لپاره تڼۍ کېکاږئ' : (started ? 'د دوام لپاره تڼۍ کېکاږئ' : 'ټولې خښتې ماتي کړئ او نمرې واخلئ');
      _centerText(canvas, size, title, 27, neon, size.height * .48);
      _centerText(canvas, size, sub, 14, Colors.white70, size.height * .48 + 42);
    } else if (notice.isNotEmpty) {
      _centerText(canvas, size, notice, 13, neon, size.height * .68);
    }
  }

  void _centerText(Canvas canvas, Size size, String value, double fontSize, Color color, double y) {
    final tp = TextPainter(text: TextSpan(text: value, style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold)), textDirection: TextDirection.rtl, textAlign: TextAlign.center)..layout(maxWidth: size.width - 30);
    tp.paint(canvas, Offset((size.width - tp.width) / 2, y));
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) => true;
}
