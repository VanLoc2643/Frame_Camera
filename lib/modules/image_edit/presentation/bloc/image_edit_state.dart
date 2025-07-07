import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

abstract class ImageEditState {}

class ImageEditInitial extends ImageEditState {}

class ImageEditLoaded extends ImageEditState {
  final File imageFile;
  final Uint8List? croppedBytes;
  final int rotation;
  final int filterIndex;
  final List<Offset> corners;
  final bool isCropping;
  final bool showFilters;
  final double imgWidth;
  final double imgHeight;

  ImageEditLoaded({
    required this.imageFile,
    this.croppedBytes,
    this.rotation = 0,
    this.filterIndex = 0,
    required this.corners,
    this.isCropping = false,
    this.showFilters = false,
    required this.imgWidth,
    required this.imgHeight,
  });
}
