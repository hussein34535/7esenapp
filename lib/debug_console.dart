import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:collection';

class LogConsole extends StatefulWidget {
  final Widget child;
  final bool show;

  const LogConsole({Key? key, required this.child, this.show = true})
      : super(key: key);

  static void log(String message) {
    _LogConsoleState.log(message);
  }

  @override
  _LogConsoleState createState() => _LogConsoleState();
}

class _LogConsoleState extends State<LogConsole> {
  static final Queue<String> _logs = Queue<String>();
  static final StreamController<void> _logStream =
      StreamController<void>.broadcast();

  static void log(String message) {
    // Keep last 50 logs
    if (_logs.length >= 50) _logs.removeFirst();
    _logs.add(
        "${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second} $message");
    _logStream.add(null);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.show) return widget.child;

    return Stack(
      fit: StackFit.expand, // Ensure child fills the screen
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 300,
          child: Material(
            color: Colors.black.withOpacity(0.8),
            child: Column(
              children: [
                Container(
                  color: Colors.grey[900],
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Debug Console",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white, size: 16),
                        onPressed: () {}, // Maybe toggle visibility
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder(
                    stream: _logStream.stream,
                    builder: (context, snapshot) {
                      return ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          // Reverse order for display (newest at bottom)
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            child: Text(
                              _logs.elementAt(index),
                              style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 12,
                                  fontFamily: 'monospace'),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
