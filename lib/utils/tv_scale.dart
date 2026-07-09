import 'package:flutter/material.dart';

class TvScale {
  static double scale(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width / 1920.0;
  }
}