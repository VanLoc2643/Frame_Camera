import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'image_edit_event.dart';
import 'image_edit_state.dart';

class ImageEditBloc extends Bloc<ImageEditEvent, ImageEditState> {
  ImageEditBloc() : super(ImageEditInitial()) {
    on<LoadImage>(_onLoadImage);
    on<RotateImage>(_onRotateImage);
    on<ApplyFilter>(_onApplyFilter);
    on<StartCrop>(_onStartCrop);
    on<UpdateCorners>(_onUpdateCorners);
    on<CropImage>(_onCropImage);
  }

  Future<void> _onLoadImage(
    LoadImage event,
    Emitter<ImageEditState> emit,
  ) async {
    final file = event.file;
    final decoded = await decodeImageFromList(await file.readAsBytes());
    final width = decoded.width.toDouble();
    final height = decoded.height.toDouble();
    final marginX = width * 0.1;
    final marginY = height * 0.1;
    emit(
      ImageEditLoaded(
        imageFile: file,
        corners: [
          Offset(marginX, marginY),
          Offset(width - marginX, marginY),
          Offset(width - marginX, height - marginY),
          Offset(marginX, height - marginY),
        ],
        imgWidth: width,
        imgHeight: height,
      ),
    );
  }

  void _onRotateImage(RotateImage event, Emitter<ImageEditState> emit) {
    if (state is ImageEditLoaded) {
      final s = state as ImageEditLoaded;
      emit(
        ImageEditLoaded(
          imageFile: s.imageFile,
          croppedBytes: s.croppedBytes,
          rotation: (s.rotation + 1) % 4,
          filterIndex: s.filterIndex,
          corners: s.corners,
          isCropping: s.isCropping,
          showFilters: s.showFilters,
          imgWidth: s.imgWidth,
          imgHeight: s.imgHeight,
        ),
      );
    }
  }

  void _onApplyFilter(ApplyFilter event, Emitter<ImageEditState> emit) {
    if (state is ImageEditLoaded) {
      final s = state as ImageEditLoaded;
      emit(
        ImageEditLoaded(
          imageFile: s.imageFile,
          croppedBytes: s.croppedBytes,
          rotation: s.rotation,
          filterIndex: event.filterIndex,
          corners: s.corners,
          isCropping: s.isCropping,
          showFilters: true,
          imgWidth: s.imgWidth,
          imgHeight: s.imgHeight,
        ),
      );
    }
  }

  void _onStartCrop(StartCrop event, Emitter<ImageEditState> emit) {
    if (state is ImageEditLoaded) {
      final s = state as ImageEditLoaded;
      emit(
        ImageEditLoaded(
          imageFile: s.imageFile,
          croppedBytes: null,
          rotation: s.rotation,
          filterIndex: s.filterIndex,
          corners: s.corners,
          isCropping: true,
          showFilters: false,
          imgWidth: s.imgWidth,
          imgHeight: s.imgHeight,
        ),
      );
    }
  }

  void _onUpdateCorners(UpdateCorners event, Emitter<ImageEditState> emit) {
    if (state is ImageEditLoaded) {
      final s = state as ImageEditLoaded;
      emit(
        ImageEditLoaded(
          imageFile: s.imageFile,
          croppedBytes: s.croppedBytes,
          rotation: s.rotation,
          filterIndex: s.filterIndex,
          corners: event.corners,
          isCropping: s.isCropping,
          showFilters: s.showFilters,
          imgWidth: s.imgWidth,
          imgHeight: s.imgHeight,
        ),
      );
    }
  }

  Future<void> _onCropImage(
    CropImage event,
    Emitter<ImageEditState> emit,
  ) async {
    if (state is ImageEditLoaded) {
      final s = state as ImageEditLoaded;
      try {
        const channel = MethodChannel('frameit/detect_corners');
        final result = await channel.invokeMethod<Uint8List>('cropImage', {
          'path': s.imageFile.path,
          'points':
              s.corners
                  .map((e) => {'x': e.dx.toInt(), 'y': e.dy.toInt()})
                  .toList(),
        });
        emit(
          ImageEditLoaded(
            imageFile: s.imageFile,
            croppedBytes: result,
            rotation: s.rotation,
            filterIndex: s.filterIndex,
            corners: s.corners,
            isCropping: false,
            showFilters: s.showFilters,
            imgWidth: s.imgWidth,
            imgHeight: s.imgHeight,
          ),
        );
      } catch (_) {}
    }
  }
}
