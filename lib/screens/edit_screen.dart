import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pro_image_editor/core/models/editor_callbacks/pro_image_editor_callbacks.dart';
import 'package:pro_image_editor/features/main_editor/main_editor.dart';
import 'package:scanner/screens/compare_screen.dart';
import 'package:scanner/utlis/filters.dart';
import 'package:scanner/widgets/crop_overlay_painter.dart';

class EditScreen extends StatefulWidget {
  final File imageFile;
  const EditScreen({super.key, required this.imageFile});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  int? _activeCornerIndex;

  File? _imageFile;
  List<Offset> _corners = [];
  Uint8List? _croppedBytes;
  int _selectedFilter = 0;
  int _rotation = 0;
  double _imageScale = 1.0;
  Offset _imageOffset = Offset.zero;
  double _imgWidth = 1;
  double _imgHeight = 1;
  bool _isCropping = false;
  bool _showFilters = false;

  // Biến hỗ trợ kéo mượt
  Offset? _cornerStart;
  // Thêm biến mới cho kính lúp
  bool _showMagnifier = false;
  Offset _magnifierPosition = Offset.zero;
  Offset _targetCornerPosition = Offset.zero;
  @override
  void initState() {
    super.initState();
    _initImage();
  }

  Future<void> _initImage() async {
    final file = widget.imageFile;
    final decoded = await decodeImageFromList(await file.readAsBytes());
    final width = decoded.width.toDouble();
    final height = decoded.height.toDouble();
    // Thêm dòng này để hiển thị thông tin ảnh
    print("Đã nạp ảnh kích thước: ${width.toInt()} x ${height.toInt()}");

    // Thay vì sát mép, lấy vào trong 10% mỗi cạnh
    final marginX = width * 0.1;
    final marginY = height * 0.1;

    setState(() {
      _imageFile = file;
      _imgWidth = width;
      _imgHeight = height;
      _corners = [
        Offset(marginX, marginY),
        Offset(width - marginX, marginY),
        Offset(width - marginX, height - marginY),
        Offset(marginX, height - marginY),
      ];
      _croppedBytes = null;
      _isCropping = false;
      _rotation = 0; // Reset rotation khi mở ảnh mới
      _selectedFilter = 0; // Reset filter khi mở ảnh mới
    });
  }

  Future<void> _detectAndSetCorners() async {
    _detectCornersNative();
  }

  // Cập nhật phương thức cropImage hiện tại
  Future<void> _cropImage() async {
    if (_imageFile == null) return;

    // Nếu đang trong chế độ cắt với góc đã phát hiện, sử dụng native implementation
    if (_isCropping && _corners.isNotEmpty) {
      await _cropImageNative();
      return;
    }

    setState(() {
      _isCropping = true;
    });

    try {
      // Hiển thị dialog hướng dẫn thay vì tự động quét
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('Crop ảnh'),
              content: Text(
                'Di chuyển các góc để crop ảnh theo mong muốn, sau đó nhấn nút "Xong".',
              ),
              actions: [
                TextButton(
                  child: Text('Đã hiểu'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
      );

      // Khởi tạo góc crop ban đầu
      if (_corners.isEmpty && _imgWidth > 0 && _imgHeight > 0) {
        final marginX = _imgWidth * 0.1;
        final marginY = _imgHeight * 0.1;
        _corners = [
          Offset(marginX, marginY),
          Offset(_imgWidth - marginX, marginY),
          Offset(_imgWidth - marginX, _imgHeight - marginY),
          Offset(marginX, _imgHeight - marginY),
        ];
      }
    } catch (e) {
      print("Lỗi khi chuẩn bị crop: $e");
    }
  }

  // Thêm phương thức để phát hiện góc từ native code
  Future<void> _detectCornersNative() async {
    if (_imageFile == null) return;

    try {
      // Hiển thị loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const Center(
              child: CircularProgressIndicator(color: Colors.green),
            ),
      );

      // Gọi phương thức native để phát hiện góc tài liệu
      const channel = MethodChannel('frameit/detect_corners');
      final corners = await channel.invokeMethod<List<dynamic>>(
        'detectDocumentCorners',
        {'path': _imageFile!.path},
      );

      // Đóng dialog loading
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (corners != null) {
        setState(() {
          // Chuyển đổi kết quả từ native thành danh sách Offset
          _corners =
              corners.map((corner) {
                final Map<dynamic, dynamic> point =
                    corner as Map<dynamic, dynamic>;
                return Offset(point['x'].toDouble(), point['y'].toDouble());
              }).toList();

          // Bật chế độ cắt để hiển thị overlay
          _isCropping = true;
        });

        print("Đã phát hiện góc tài liệu từ native: $_corners");
      } else {
        print("Không phát hiện được góc tài liệu");
      }
    } catch (e) {
      // Đóng dialog nếu có lỗi
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      print("Lỗi khi phát hiện góc tài liệu: $e");
    }
  }

  // Thêm phương thức cắt ảnh sử dụng native implementation
  Future<void> _cropImageNative() async {
    if (_imageFile == null || _corners.isEmpty) return;

    try {
      // Hiển thị loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const Center(
              child: CircularProgressIndicator(color: Colors.green),
            ),
      );

      // Sử dụng native code để cắt ảnh
      const channel = MethodChannel('frameit/detect_corners');
      final result = await channel.invokeMethod<Uint8List>('cropImage', {
        'path': _imageFile!.path,
        'points':
            _corners
                .map((e) => {'x': e.dx.toInt(), 'y': e.dy.toInt()})
                .toList(),
      });

      // Đóng dialog loading
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (result != null) {
        setState(() {
          _croppedBytes = result;
          _isCropping = false;
          _rotation = 0; // Reset rotation khi crop ảnh mới
        });

        // Cập nhật thông số kích thước ảnh mới
        final decoded = await decodeImageFromList(result);
        setState(() {
          _imgWidth = decoded.width.toDouble();
          _imgHeight = decoded.height.toDouble();
        });

        print("Đã cắt ảnh thành công với native implementation");
      }
    } catch (e) {
      // Đóng dialog loading nếu có lỗi
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      print("Lỗi khi cắt ảnh với native implementation: $e");
    }
  }

  Widget _buildFilterSelector(Uint8List imageBytes) {
    // Không thay đổi phần này
    return Container(
      height: 120.h,
      color: Colors.black87,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: imageFilters.length,
        itemBuilder: (context, index) {
          final filter = imageFilters[index];
          final isSelected = index == _selectedFilter;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = index;
              });
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

  @override
  Widget build(BuildContext context) {
    // Phần UI build không thay đổi nhiều
    final imageBytes =
        _croppedBytes ??
        (_imageFile != null ? _imageFile!.readAsBytesSync() : null);

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        foregroundColor: Colors.white,
        elevation: 5,
        actions: [
          if (_isCropping)
            Padding(
              padding: EdgeInsets.all(12.w),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 60.w, maxHeight: 80.h),
                child: ElevatedButton(
                  onPressed: _cropImageNative,
                  child: Text(
                    "Xong",
                    style: TextStyle(fontSize: 12.sp, color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: 6.h,
                      horizontal: 12.w,
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
            if (_imageFile != null)
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color.fromARGB(255, 0, 0, 0),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final boxWidth = constraints.maxWidth;
                            final boxHeight = constraints.maxHeight;
                            final scale =
                                (_imgWidth == 0 || _imgHeight == 0)
                                    ? 1.0
                                    : (boxWidth / _imgWidth).clamp(
                                      0.0,
                                      boxHeight / _imgHeight,
                                    );
                            final imgDisplayWidth = _imgWidth * scale;
                            final imgDisplayHeight = _imgHeight * scale;
                            final offset = Offset(
                              (boxWidth - imgDisplayWidth) / 2,
                              (boxHeight - imgDisplayHeight) / 2,
                            );
                            _imageScale = scale;
                            _imageOffset = offset;

                            return Stack(
                              children: [
                                Positioned(
                                  left: offset.dx,
                                  top: offset.dy,
                                  width: imgDisplayWidth,
                                  height: imgDisplayHeight,
                                  child: RotatedBox(
                                    quarterTurns: _rotation,
                                    child: ColorFiltered(
                                      colorFilter:
                                          imageFilters[_selectedFilter]['filter']
                                              as ColorFilter? ??
                                          const ColorFilter.mode(
                                            Colors.transparent,
                                            BlendMode.dst,
                                          ),
                                      child:
                                          _croppedBytes == null
                                              ? Image.file(
                                                _imageFile!,
                                                fit: BoxFit.contain,
                                              )
                                              : Image.memory(
                                                _croppedBytes!,
                                                fit: BoxFit.contain,
                                              ),
                                    ),
                                  ),
                                ),
                                if (_isCropping && _croppedBytes == null) ...[
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: CropOverlayPainter(
                                        points:
                                            _corners
                                                .map((e) => e * scale + offset)
                                                .toList(),
                                      ),
                                    ),
                                  ),
                                  // Các điểm điều khiển góc
                                  if (_isCropping && _croppedBytes == null)
                                    ..._corners.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final point =
                                          entry.value * scale + offset;
                                      return Positioned(
                                        left: point.dx - 20.w,
                                        top: point.dy - 20.h,
                                        child: GestureDetector(
                                          onPanStart: (details) {
                                            setState(() {
                                              _cornerStart = _corners[index];

                                              // Bật kính lúp khi bắt đầu kéo
                                              _showMagnifier = true;
                                              _magnifierPosition =
                                                  details.globalPosition;
                                              _targetCornerPosition =
                                                  _corners[index];
                                              _activeCornerIndex = index;
                                            });
                                          },
                                          onPanUpdate: (details) {
                                            setState(() {
                                              final dx =
                                                  details.delta.dx /
                                                  _imageScale;
                                              final dy =
                                                  details.delta.dy /
                                                  _imageScale;

                                              // Giới hạn phạm vi di chuyển
                                              final newX = (_corners[index].dx +
                                                      dx)
                                                  .clamp(0.0, _imgWidth);
                                              final newY = (_corners[index].dy +
                                                      dy)
                                                  .clamp(0.0, _imgHeight);

                                              _corners[index] = Offset(
                                                newX,
                                                newY,
                                              );

                                              // Cập nhật vị trí kính lúp theo ngón tay
                                              _magnifierPosition =
                                                  details.globalPosition;
                                              _targetCornerPosition =
                                                  _corners[index];

                                              // Thêm log để debug
                                              print(
                                                "Corner moving to: $_targetCornerPosition",
                                              );
                                            });
                                          },
                                          onPanEnd: (_) {
                                            setState(() {
                                              _activeCornerIndex = null;

                                              // Tắt kính lúp khi thả
                                              _showMagnifier = false;
                                            });
                                          },
                                          child: Container(
                                            width: 60.w,
                                            height: 60.h,
                                            decoration: BoxDecoration(
                                              color: Colors.transparent,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                ],

                                // Thêm kính lúp vào cuối Stack để nó hiển thị phía trên
                                if (_showMagnifier) _buildMagnifier(),
                              ],
                            );
                          },
                        ),
                      ),
                      if (_showFilters && imageBytes != null)
                        _buildFilterSelector(imageBytes),
                      buildBottomToolBar(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMagnifier() {
    if (!_showMagnifier || _imageFile == null) return const SizedBox.shrink();

    // Đảm bảo chúng ta có dữ liệu ảnh để hiển thị
    final imageBytes = _croppedBytes ?? _imageFile!.readAsBytesSync();

    return Positioned(
      left: _magnifierPosition.dx - 60,
      top: _magnifierPosition.dy - 220, // Tăng khoảng cách để không che tay
      child: Stack(
        children: [
          // Kính lúp cơ bản với hình ảnh phóng to
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,

              border: Border.all(color: Colors.green, width: 2),
            ),
            // ClipOval để cắt hình ảnh thành hình tròn
            child: ClipOval(
              child: Image.memory(
                imageBytes,
                fit: BoxFit.none,
                width: _imgWidth * 2.5,
                height: _imgHeight * 2.5,
                alignment: FractionalOffset(
                  _targetCornerPosition.dx / _imgWidth,
                  _targetCornerPosition.dy / _imgHeight,
                ),
              ),
            ),
          ),

          // Lớp overlay vẽ đường kẻ và điểm
          Positioned.fill(
            child: ClipOval(
              child: CustomPaint(
                painter: MagnifierOverlayPainter(
                  activeCornerIndex: _activeCornerIndex,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBottomToolBar() {
    final tools = [
      {
        'icon': Icons.document_scanner,
        'label': 'Scan',
      }, // Thay đổi label từ Crop sang Scan
      {'icon': Icons.crop, 'label': 'Crop'}, // Thêm nút Crop mới
      {'icon': Icons.filter, 'label': 'Filter'},
      {'icon': Icons.rotate_right, 'label': 'Rotate'},
      {'icon': Icons.brightness_6, 'label': 'Light'},
      {'icon': Icons.tune, 'label': 'Adjust'},
      {'icon': Icons.mode_edit_outline_sharp, 'label': 'edit'},
      {'icon': Icons.compare, 'label': 'Compare'},
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
            onTap: () async {
              if (tool['label'] == 'Scan') {
                // Giữ nguyên phần Scan
                try {
                  // Sử dụng ImagePicker thay vì cunning_document_scanner
                  final picked = await ImagePicker().pickImage(
                    source: ImageSource.camera,
                    imageQuality: 100,
                    maxWidth: 2000,
                    maxHeight: 2000,
                  );

                  if (picked != null) {
                    final file = File(picked.path);
                    final bytes = await file.readAsBytes();

                    setState(() {
                      _imageFile = file;
                      _croppedBytes = null; // Đặt về null để hiển thị ảnh gốc
                      _rotation = 0;
                      _showFilters = false;
                    });

                    // Cập nhật kích thước ảnh
                    final decoded = await decodeImageFromList(bytes);
                    final width = decoded.width.toDouble();
                    final height = decoded.height.toDouble();

                    setState(() {
                      _imgWidth = width;
                      _imgHeight = height;
                      // Đặt góc crop mặc định
                      final marginX = width * 0.1;
                      final marginY = height * 0.1;
                      _corners = [
                        Offset(marginX, marginY),
                        Offset(width - marginX, marginY),
                        Offset(width - marginX, height - marginY),
                        Offset(marginX, height - marginY),
                      ];
                    });

                    print("Đã chụp ảnh mới với ImagePicker");
                  }
                } catch (e) {
                  print("Lỗi khi quét tài liệu: $e");
                }
              } else if (tool['label'] == 'Crop') {
                // Sử dụng native detection thay vì cunning_document_scanner
                _detectCornersNative();
              } else if (tool['label'] == 'Compare') {
                if (_imageFile != null) {
                  final originalBytes = await _imageFile!.readAsBytes();
                  final editedBytes = _croppedBytes ?? originalBytes;

                  // Hiển thị dialog so sánh
                  showDialog(
                    context: context,
                    builder:
                        (context) => CompareScreen(
                          originalBytes: originalBytes,
                          editedBytes: editedBytes,
                        ),
                  );
                }
              } else if (tool['label'] == 'Filter') {
                setState(() {
                  _showFilters = !_showFilters;
                  _isCropping = false;
                });
              } else if (tool['label'] == 'Rotate') {
                setState(() {
                  _rotation = (_rotation + 1) % 4;
                });
              } else if (tool['label'] == 'edit') {
                if (_imageFile != null) {
                  Uint8List imageBytes =
                      _croppedBytes ?? await _imageFile!.readAsBytes();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ProImageEditor.memory(
                            imageBytes,
                            callbacks: ProImageEditorCallbacks(
                              onImageEditingComplete: (
                                Uint8List editedBytes,
                              ) async {
                                setState(() {
                                  _croppedBytes = editedBytes;
                                });
                                Navigator.pop(context);
                                return;
                              },
                            ),
                          ),
                    ),
                  );
                }
              } else if (tool['label'] == 'Adjust') {
                if (_imageFile != null) {
                  Uint8List imageBytes =
                      _croppedBytes ?? await _imageFile!.readAsBytes();
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ImageEditor(image: imageBytes),
                    ),
                  );
                  if (result != null && result is Uint8List) {
                    setState(() {
                      _croppedBytes = result;
                    });
                  }
                }
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
                    color: const Color.fromARGB(255, 255, 255, 255),
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

class MagnifierOverlayPainter extends CustomPainter {
  final int? activeCornerIndex; // Thêm tham số để biết góc nào đang được kéo

  MagnifierOverlayPainter({this.activeCornerIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Vẽ các đường kẻ xanh lá cây đậm hơn
    final linePaint =
        Paint()
          ..color = Colors.green
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    // // Vẽ điểm trắng ở giữa
    // final dotPaint =
    //     Paint()
    //       ..color = Colors.white
    //       ..style = PaintingStyle.fill;
    // canvas.drawCircle(center, 6, dotPaint);

    // // Vẽ viền đen mỏng cho điểm
    // final borderPaint =
    //     Paint()
    //       ..color = Colors.black
    //       ..style = PaintingStyle.stroke
    //       ..strokeWidth = 1;
    // canvas.drawCircle(center, 6, borderPaint);

    // Xác định kiểu góc vuông dựa vào index của góc đang được kéo
    // 0: góc trên trái, 1: góc trên phải, 2: góc dưới phải, 3: góc dưới trái
    switch (activeCornerIndex) {
      case 0: // Góc trên trái - vẽ góc vuông mở ra phải dưới
        canvas.drawLine(center, Offset(center.dx + 50, center.dy), linePaint);
        canvas.drawLine(center, Offset(center.dx, center.dy + 50), linePaint);
        break;

      case 1: // Góc trên phải - vẽ góc vuông mở ra trái dưới
        canvas.drawLine(center, Offset(center.dx - 50, center.dy), linePaint);
        canvas.drawLine(center, Offset(center.dx, center.dy + 50), linePaint);
        break;

      case 2: // Góc dưới phải - vẽ góc vuông mở ra trái trên
        canvas.drawLine(center, Offset(center.dx - 50, center.dy), linePaint);
        canvas.drawLine(center, Offset(center.dx, center.dy - 50), linePaint);
        break;

      case 3: // Góc dưới trái - vẽ góc vuông mở ra phải trên
        canvas.drawLine(center, Offset(center.dx + 50, center.dy), linePaint);
        canvas.drawLine(center, Offset(center.dx, center.dy - 50), linePaint);
        break;

      default: // Nếu không xác định được góc, vẽ hình chữ thập
        canvas.drawLine(
          Offset(center.dx - 50, center.dy),
          Offset(center.dx + 50, center.dy),
          linePaint,
        );
        canvas.drawLine(
          Offset(center.dx, center.dy - 50),
          Offset(center.dx, center.dy + 50),
          linePaint,
        );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
