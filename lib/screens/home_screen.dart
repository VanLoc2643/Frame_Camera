import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scanner/screens/edit_screen.dart';
import 'package:scanner/widget/custom_appbar_widget.dart';
import 'package:scanner/widget/custom_navbar_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      // Sử dụng ImagePicker thông thường cho cả camera và thư viện
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 100,
        maxWidth: 2000,
        maxHeight: 2000,
      );

      if (picked != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditScreen(imageFile: File(picked.path)),
          ),
        );
      }
    } catch (e) {
      print("Lỗi khi chụp hoặc chọn ảnh: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Phần UI không thay đổi
    return Scaffold(
      appBar: CustomAppBar(),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 80.h,
                    child: ElevatedButton(
                      onPressed: () {
                        _pickImage(context, ImageSource.camera);
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        padding: EdgeInsets.zero,
                        elevation: 4,
                        backgroundColor: const Color.fromARGB(
                          173,
                          155,
                          69,
                          246,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt,
                            size: 28.sp,
                            color: const Color.fromARGB(255, 0, 0, 0),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            "Camera",
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  flex: 1,
                  child: ElevatedButton(
                    onPressed: () => _pickImage(context, ImageSource.gallery),
                    // Phần style không thay đổi
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      elevation: 4,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_library,
                            size: 28.sp,
                            color: Colors.white,
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            "Album",
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 26.h),
            Text(
              "Dự án:",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: 0,
        onItemTapped: (p0) {},
      ),
    );
  }
}
