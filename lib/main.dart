import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: BucketGame(),
      debugShowCheckedModeBanner: false,
    );
  }
}

enum BallType { normal, bonus, bomb }

class Ball {
  double x;
  double y;
  final BallType type;
  Ball(this.x, this.y, this.type);
}

class BucketGame extends StatefulWidget {
  const BucketGame({Key? key}) : super(key: key);

  @override
  _BucketGameState createState() => _BucketGameState();
}

class _BucketGameState extends State<BucketGame> {
  final List<Ball> _balls = [];
  Timer? _spawnTimer;
  Timer? _gameTimer;
  final AudioCache _audio = AudioCache(prefix: 'assets/sounds/');
  final Random _rand = Random();

  int _score = 0;
  int _missed = 0;
  int _level = 1;
  double _bucketX = 0.5;
  bool _isGameOver = false;

  static const double _ballRadius = 20;
  static const double _bucketWidth = 80;
  static const double _bucketHeight = 48;
  static const int _maxMissed = 3;

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  void _startGame() {
    _score = 0;
    _missed = 0;
    _level = 1;
    _bucketX = 0.5;
    _isGameOver = false;
    _balls.clear();
    _spawnTimer?.cancel();
    _gameTimer?.cancel();
    _scheduleSpawn();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (_) => _updateGame());
    setState(() {});
  }

  void _scheduleSpawn() {
    final interval = max(600 - (_level - 1) * 50, 200);
    _spawnTimer?.cancel();
    _spawnTimer = Timer.periodic(Duration(milliseconds: interval), (_) {
      final t = _rand.nextDouble();
      final type = t < 0.1
          ? BallType.bomb
          : (t < 0.3 ? BallType.bonus : BallType.normal);
      _balls.add(Ball(_rand.nextDouble(), 0, type));
    });
  }

  void _updateGame() {
    if (_isGameOver) return;
    final size = MediaQuery.of(context).size;
    final bucketCenter = _bucketX * size.width;

    for (var ball in List<Ball>.from(_balls)) {
      ball.y += 0.002 + _level * 0.0005;
      final by = ball.y * size.height;
      if (by + _ballRadius >= size.height - _bucketHeight - 20) {
        final bx = ball.x * size.width;
        if (bx >= bucketCenter - _bucketWidth / 2 && bx <= bucketCenter + _bucketWidth / 2) {
          _catch(ball);
        } else {
          _miss(ball);
        }
        _balls.remove(ball);
      }
    }

    if (_score >= _level * 10) {
      _level++;
      _scheduleSpawn();
    }

    if (_missed >= _maxMissed) {
      _gameOver();
    }

    setState(() {});
  }

  void _catch(Ball ball) {
    switch (ball.type) {
      case BallType.normal:
        _score += 1;
        _audio.play('catch.wav');
        break;
      case BallType.bonus:
        _score += 5;
        _audio.play('bonus.wav');
        break;
      case BallType.bomb:
        _score = max(0, _score - 5);
        _audio.play('bomb.wav');
        break;
    }
  }

  void _miss(Ball ball) {
    if (ball.type != BallType.bomb) {
      _missed++;
      _audio.play('miss.wav');
    }
  }

  void _gameOver() {
    _isGameOver = true;
    _spawnTimer?.cancel();
    _gameTimer?.cancel();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black87,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Game Over', style: TextStyle(fontSize: 24, color: Colors.white)),
            Text('Score: $_score', style: const TextStyle(fontSize: 20, color: Colors.white)),
            ElevatedButton(
              onPressed: () { Navigator.of(context).pop(); _startGame(); },
              child: const Text('Replay'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBall(Ball ball) {
    switch (ball.type) {
      case BallType.bonus:
        return Container(
          width: _ballRadius * 2,
          height: _ballRadius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Colors.yellow, Colors.orange],
              center: Alignment(-0.2, -0.2),
              radius: 0.8,
            ),
            boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.7), blurRadius: 8)],
          ),
          child: const Center(child: Icon(Icons.star, color: Colors.white, size: 16)),
        );
      case BallType.bomb:
        return Container(
          width: _ballRadius * 2,
          height: _ballRadius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8)],
          ),
          child: const Center(child: Icon(Icons.warning, color: Colors.red, size: 16)),
        );
      default:
        return Container(
          width: _ballRadius * 2,
          height: _ballRadius * 2,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.white70, blurRadius: 8)],
          ),
        );
    }
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    _gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _bucketX = (_bucketX + details.delta.dx / size.width).clamp(0.0, 1.0);
          });
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                ),
              ),
            ),
            for (var ball in _balls)
              Positioned(
                left: ball.x * size.width - _ballRadius,
                top: ball.y * size.height,
                child: _buildBall(ball),
              ),
            Positioned(
              bottom: 20,
              left: _bucketX * size.width - _bucketWidth / 2,
              child: Image.asset('assets/images/bucket.png', width: _bucketWidth, height: _bucketHeight),
            ),
            Positioned(
              top: 40,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Score: $_score', style: TextStyle(color: Colors.white, fontSize: 18)),
                  Text('Missed: $_missed', style: TextStyle(color: Colors.white, fontSize: 18)),
                  Text('Level: $_level', style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
