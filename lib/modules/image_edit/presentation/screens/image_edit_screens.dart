import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../bloc/image_edit_bloc.dart';
import '../bloc/image_edit_event.dart';
import '../bloc/image_edit_state.dart';

class ImageEditPage extends StatelessWidget {
  final File imageFile;
  const ImageEditPage({super.key, required this.imageFile});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ImageEditBloc()..add(LoadImage(imageFile)),
      child: BlocBuilder<ImageEditBloc, ImageEditState>(
        builder: (context, state) {
          if (state is ImageEditInitial) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (state is ImageEditLoaded) {
            final imgBytes =
                state.croppedBytes ?? state.imageFile.readAsBytesSync();
            final filters = [
              {'name': 'Gốc', 'filter': null},
              {
                'name': 'Grayscale',
                'filter': const ColorFilter.matrix([
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
              },
              // ... các filter khác ...
            ];
            return Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 5,
                actions: [
                  if (state.isCropping)
                    Padding(
                      padding: EdgeInsets.all(12.w),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 60.w,
                          maxHeight: 86.h,
                        ),
                        child: ElevatedButton.icon(
                          onPressed:
                              () => context.read<ImageEditBloc>().add(
                                CropImage(),
                              ),
                          icon: Icon(Icons.check, color: Colors.black),
                          label: const Text(''),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: 6.h,
                              horizontal: 11.w,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              body: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final boxWidth = constraints.maxWidth;
                          final boxHeight = constraints.maxHeight;
                          final scale =
                              (state.imgWidth == 0 || state.imgHeight == 0)
                                  ? 1.0
                                  : (boxWidth / state.imgWidth).clamp(
                                    0.0,
                                    boxHeight / state.imgHeight,
                                  );
                          final imgDisplayWidth = state.imgWidth * scale;
                          final imgDisplayHeight = state.imgHeight * scale;
                          final offset = Offset(
                            (boxWidth - imgDisplayWidth) / 2,
                            (boxHeight - imgDisplayHeight) / 2,
                          );
                          return Stack(
                            children: [
                              Positioned(
                                left: offset.dx,
                                top: offset.dy,
                                width: imgDisplayWidth,
                                height: imgDisplayHeight,
                                child: Transform.rotate(
                                  angle:
                                      (state.rotation * 90) *
                                      3.1415926535 /
                                      180,
                                  child: ColorFiltered(
                                    colorFilter:
                                        filters[state.filterIndex]['filter']
                                            as ColorFilter? ??
                                        const ColorFilter.mode(
                                          Colors.transparent,
                                          BlendMode.dst,
                                        ),
                                    child: Image.memory(
                                      imgBytes,
                                      fit: BoxFit.fill,
                                    ),
                                  ),
                                ),
                              ),
                              if (state.isCropping &&
                                  state.corners.isNotEmpty) ...[
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: CropOverlayPainter(
                                      points:
                                          state.corners
                                              .map((e) => e * scale + offset)
                                              .toList(),
                                    ),
                                  ),
                                ),
                                ...state.corners.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final point = entry.value * scale + offset;
                                  return Positioned(
                                    left: point.dx - 20.w,
                                    top: point.dy - 20.h,
                                    child: GestureDetector(
                                      onPanStart: (details) {
                                        context.read<ImageEditBloc>().add(
                                          UpdateCorners(
                                            List<Offset>.from(state.corners),
                                          ),
                                        );
                                      },
                                      onPanUpdate: (details) {
                                        final newCorners = List<Offset>.from(
                                          state.corners,
                                        );
                                        final delta = details.delta / scale;
                                        newCorners[index] = Offset(
                                          (state.corners[index].dx + delta.dx)
                                              .clamp(0, state.imgWidth),
                                          (state.corners[index].dy + delta.dy)
                                              .clamp(0, state.imgHeight),
                                        );
                                        context.read<ImageEditBloc>().add(
                                          UpdateCorners(newCorners),
                                        );
                                      },
                                      child: Container(
                                        width: 40.w,
                                        height: 40.h,
                                        decoration: const BoxDecoration(
                                          color: Colors.transparent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                    if (state.showFilters)
                      _buildFilterSelector(
                        context,
                        imgBytes,
                        state.filterIndex,
                        filters,
                      ),
                    _buildBottomToolBar(context, state, filters),
                  ],
                ),
              ),
            );
          }
          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildFilterSelector(
    BuildContext context,
    Uint8List imageBytes,
    int selected,
    List<Map<String, dynamic>> filters,
  ) {
    return Container(
      height: 120.h,
      color: Colors.black87,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = index == selected;
          return GestureDetector(
            onTap: () {
              context.read<ImageEditBloc>().add(ApplyFilter(index));
            },
            child: Container(
              width: 80.w,
              margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
              child: Column(
                children: [
                  Container(
                    width: 60.w,
                    height: 60.h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.white24,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: ColorFiltered(
                        colorFilter:
                            filter['filter'] as ColorFilter? ??
                            const ColorFilter.mode(
                              Colors.transparent,
                              BlendMode.dst,
                            ),
                        child: Image.memory(imageBytes, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    filter['name'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.blue : Colors.white,
                      fontSize: 10.sp,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomToolBar(
    BuildContext context,
    ImageEditLoaded state,
    List<Map<String, dynamic>> filters,
  ) {
    final tools = [
      {'icon': Icons.crop, 'label': 'Crop'},
      {'icon': Icons.filter, 'label': 'Filter'},
      {'icon': Icons.rotate_right, 'label': 'Rotate'},
      // ... các tool khác ...
    ];

    return Container(
      color: const Color.fromARGB(255, 28, 27, 26),
      height: 100.h,
      padding: EdgeInsets.symmetric(horizontal: 15.w),
      alignment: Alignment.topCenter,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tools.length,
        separatorBuilder: (_, __) => SizedBox(width: 12.w),
        itemBuilder: (context, index) {
          final tool = tools[index];
          return GestureDetector(
            onTap: () {
              if (tool['label'] == 'Crop') {
                context.read<ImageEditBloc>().add(StartCrop());
              } else if (tool['label'] == 'Filter') {
                context.read<ImageEditBloc>().add(
                  ApplyFilter(state.filterIndex),
                );
              } else if (tool['label'] == 'Rotate') {
                context.read<ImageEditBloc>().add(RotateImage());
              }
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black12,
                  radius: 28.r,
                  child: Icon(
                    tool['icon'] as IconData,
                    size: 26.sp,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  tool['label'] as String,
                  style: TextStyle(fontSize: 12.sp),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class CropOverlayPainter extends CustomPainter {
  final List<Offset> points;
  CropOverlayPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length != 4) return;

    final paint =
        Paint()
          ..color = Colors.green
          ..strokeWidth = 3.w;
    for (int i = 0; i < 4; i++) {
      canvas.drawLine(points[i], points[(i + 1) % 4], paint);
    }

    final dotPaint =
        Paint()
          ..color = Colors.red
          ..style = PaintingStyle.fill;
    for (final p in points) {
      canvas.drawCircle(p, 8.r, dotPaint);
      canvas.drawCircle(
        p,
        10.r,
        Paint()
          ..color = Colors.white.withOpacity(0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.w,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
