import 'dart:typed_data';

import 'package:before_after/before_after.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CompareScreen extends StatefulWidget {
  final Uint8List originalBytes;
  final Uint8List editedBytes;

  const CompareScreen({
    Key? key,
    required this.originalBytes,
    required this.editedBytes,
  }) : super(key: key);

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  double _value = 0.5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'So sánh trước và sau',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.white24, width: 1.w),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: BeforeAfter(
                  value: _value,
                  before: Image.memory(
                    widget.originalBytes,
                    fit: BoxFit.contain,
                  ),
                  after: Image.memory(widget.editedBytes, fit: BoxFit.contain),
                  onValueChanged: (value) {
                    setState(() => _value = value);
                  },
                  thumbColor: Colors.green,
                  thumbHeight: 40.h,
                  thumbWidth: 40.w,
                  overlayColor: MaterialStateProperty.all(
                    Colors.black.withOpacity(0.3),
                  ),
                  direction: SliderDirection.horizontal,
                  trackWidth: 2.w,
                  trackColor: Colors.white,
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
            color: Colors.black,
            child: Column(
              children: [
                Text(
                  'Kéo thanh trượt để so sánh ảnh',
                  style: TextStyle(color: Colors.white70, fontSize: 14.sp),
                ),
                SizedBox(height: 20.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLegend('Gốc', Colors.blue),
                    _buildLegend('Đã chỉnh sửa', Colors.green),
                  ],
                ),
                SizedBox(height: 30.h),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    minimumSize: Size(200.w, 50.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25.r),
                    ),
                  ),
                  child: Text(
                    'Quay lại chỉnh sửa',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16.w,
          height: 16.h,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 8.w),
        Text(label, style: TextStyle(color: Colors.white, fontSize: 14.sp)),
      ],
    );
  }
}
