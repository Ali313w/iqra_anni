import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async';

class GeminiBackground extends StatefulWidget {
  final double intensity;
  const GeminiBackground({super.key, this.intensity = 0.0});

  @override
  State<GeminiBackground> createState() => _GeminiBackgroundState();
}

class _GeminiBackgroundState extends State<GeminiBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  FragmentShader? _shader;
  late Ticker _ticker;
  double _time = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadShader();
    _ticker = createTicker((elapsed) {
      setState(() {
        _time = elapsed.inMilliseconds / 1000.0;
      });
    });
    _ticker.start();
  }

  Future<void> _loadShader() async {
    final program = await FragmentProgram.fromAsset('assets/shaders/gemini_wave.frag');
    setState(() {
      _shader = program.fragmentShader();
    });
  }

  // هذه الخلفية المتحركة تُعيد رسم الشاشة كاملة عبر shader في كل إطار بلا
  // توقف. كانت تستمر بذلك حتى أثناء تصغير التطبيق أو انتقاله للخلفية، وهو
  // استهلاك غير ضروري للمعالج/الرسوميات والبطارية لا يراه المستخدم أصلاً.
  // نوقف الـ ticker حين لا يكون التطبيق في المقدمة ونستأنفه عند العودة.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_ticker.isActive) _ticker.start();
    } else {
      if (_ticker.isActive) _ticker.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_shader == null) return Container(color: const Color(0xFF020308));

    return CustomPaint(
      painter: GeminiWavePainter(
        shader: _shader!,
        time: _time,
        intensity: widget.intensity,
      ),
      child: Container(),
    );
  }
}

class GeminiWavePainter extends CustomPainter {
  final FragmentShader shader;
  final double time;
  final double intensity;

  GeminiWavePainter({
    required this.shader,
    required this.time,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, time); // uTime
    shader.setFloat(1, size.width); // uResolution.x
    shader.setFloat(2, size.height); // uResolution.y
    shader.setFloat(3, intensity); // uIntensity

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant GeminiWavePainter oldDelegate) => true;
}
