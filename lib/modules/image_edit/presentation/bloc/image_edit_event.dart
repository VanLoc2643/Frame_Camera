import 'dart:io';

import 'package:flutter/material.dart';

abstract class ImageEditEvent {}

class LoadImage extends ImageEditEvent {
  final File file;
  LoadImage(this.file);
}

class RotateImage extends ImageEditEvent {}

class ApplyFilter extends ImageEditEvent {
  final int filterIndex;
  ApplyFilter(this.filterIndex);
}

class StartCrop extends ImageEditEvent {}

class UpdateCorners extends ImageEditEvent {
  final List<Offset> corners;
  UpdateCorners(this.corners);
}

class CropImage extends ImageEditEvent {}
