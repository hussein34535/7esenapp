import 'package:flutter/material.dart';
import 'vidstack_player_impl_stub.dart'
    if (dart.library.html) 'vidstack_player_impl_web.dart' as impl;

class VidstackPlayerWidget extends StatelessWidget {
  final String url;
  const VidstackPlayerWidget({required this.url, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return impl.VidstackPlayerImpl(url: url);
  }
}
