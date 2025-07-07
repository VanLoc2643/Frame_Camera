package com.example.scanner

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.opencv.android.OpenCVLoader
import org.opencv.android.Utils
import org.opencv.core.*
import org.opencv.imgproc.Imgproc
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "frameit/detect_corners"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Init OpenCV
        if (!OpenCVLoader.initDebug()) {
            println("OpenCV failed to init")
        } else {
            println("OpenCV initialized successfully")
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            println("Method called: ${call.method}")
            
            when (call.method) {
                "cropImage" -> {
                    val path = call.argument<String>("path")!!
                    println("cropImage called with path: $path")
                    val points = call.argument<List<Map<String, Int>>>("points")!!
                    val croppedBytes = cropImage(path, points)
                    result.success(croppedBytes)
                } 
                "detectDocumentCorners" -> {
                    try {
                        val path = call.argument<String>("path")!!
                        println("detectDocumentCorners called with path: $path")
                        
                        // Kiểm tra file
                        val file = File(path)
                        if (!file.exists()) {
                            println("File không tồn tại: $path")
                            result.error("FILE_NOT_FOUND", "File không tồn tại", null)
                            return@setMethodCallHandler
                        }
                        
                        println("File size: ${file.length()} bytes")
                        
                        val corners = detectDocumentCorners(path)
                        println("Detected corners: $corners")
                        result.success(corners)
                    } catch (e: Exception) {
                        println("Error in detectDocumentCorners method: ${e.message}")
                        e.printStackTrace()
                        result.error("DETECTION_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun detectDocumentCorners(path: String): List<Map<String, Int>> {
        try {
            println("Starting document corner detection")
            
            // Đọc ảnh với độ phân giải đầy đủ
            val options = BitmapFactory.Options().apply {
                inSampleSize = 1 // Giữ độ phân giải đầy đủ để tăng độ chính xác
            }
            val bitmap = BitmapFactory.decodeFile(path, options)
            println("Image loaded: ${bitmap.width}x${bitmap.height}")
            
            val originalWidth = bitmap.width
            val originalHeight = bitmap.height
            
            // Chuyển sang Mat
            val src = Mat()
            Utils.bitmapToMat(bitmap, src)
            
            // Chuyển sang grayscale
            val gray = Mat()
            Imgproc.cvtColor(src, gray, Imgproc.COLOR_BGR2GRAY)
            
            // Tăng cường tương phản
            val enhanced = Mat()
            Imgproc.equalizeHist(gray, enhanced)
            
            // THAY ĐỔI: Xử lý khác nhau dựa trên kích thước ảnh
            if (originalWidth > 2000 || originalHeight > 2000) {
                println("Ảnh có độ phân giải cao, điều chỉnh xử lý")
                
                // Giảm nhiễu với GaussianBlur (kernel lớn hơn cho ảnh độ phân giải cao)
                Imgproc.GaussianBlur(enhanced, enhanced, Size(7.0, 7.0), 0.0)
                
                // Phát hiện cạnh với Canny (ngưỡng thấp hơn)
                val edges = Mat()
                Imgproc.Canny(enhanced, edges, 20.0, 120.0)
                
                // Áp dụng phép đóng (closing) để kết nối các cạnh đứt đoạn
                val kernel = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(11.0, 11.0))
                val closed = Mat()
                Imgproc.morphologyEx(edges, closed, Imgproc.MORPH_CLOSE, kernel)
                
                // Áp dụng phép giãn (dilate) để làm dày cạnh
                val dilated = Mat()
                Imgproc.dilate(closed, dilated, kernel)
                
                // Tìm contours
                val contours = ArrayList<MatOfPoint>()
                val hierarchy = Mat()
                Imgproc.findContours(dilated, contours, hierarchy, Imgproc.RETR_LIST, Imgproc.CHAIN_APPROX_SIMPLE)
                println("Found ${contours.size} contours")
                
                // THAY ĐỔI: Lọc contours theo tiêu chí mới
                val filteredContours = contours.filter { contour ->
                    val area = Imgproc.contourArea(contour)
                    val minArea = originalWidth * originalHeight * 0.02 // Giảm ngưỡng xuống 2%
                    area > minArea
                }.sortedByDescending { Imgproc.contourArea(it) }
                
                println("Filtered to ${filteredContours.size} contours")
                
                // Duyệt qua các contour đã lọc để tìm hình dạng tốt nhất
                for (contour in filteredContours) {
                    val peri = Imgproc.arcLength(MatOfPoint2f(*contour.toArray()), true)
                    val approx = MatOfPoint2f()
                    Imgproc.approxPolyDP(MatOfPoint2f(*contour.toArray()), approx, 0.02 * peri, true)
                    
                    // Tìm hình dạng có 4 điểm hoặc gần như thế
                    if (approx.toArray().size >= 3 && approx.toArray().size <= 6) {
                        println("Found shape with ${approx.toArray().size} points")
                        
                        // Xác định 4 góc chính từ điểm
                        val points = approx.toArray()
                        
                        // Sử dụng convex hull để đảm bảo hình dạng lồi
                        val hull = MatOfInt()
                        Imgproc.convexHull(MatOfPoint(*points), hull)
                        val hullPoints = hull.toArray().map { points[it] }.toTypedArray()
                        
                        // Lấy ra 4 điểm quan trọng nhất
                        val finalPoints = if (hullPoints.size == 4) {
                            hullPoints
                        } else if (hullPoints.size > 4) {
                            println("Reducing from ${hullPoints.size} points to 4")
                            // Tính trung tâm
                            val centerX = hullPoints.sumOf { it.x } / hullPoints.size
                            val centerY = hullPoints.sumOf { it.y } / hullPoints.size
                            
                            // Phân loại các điểm theo góc phần tư
                            val topLeft = hullPoints.minByOrNull { 
                                Math.sqrt(Math.pow(it.x - 0, 2.0) + Math.pow(it.y - 0, 2.0)) 
                            }!!
                            val topRight = hullPoints.minByOrNull { 
                                Math.sqrt(Math.pow(it.x - originalWidth, 2.0) + Math.pow(it.y - 0, 2.0)) 
                            }!!
                            val bottomRight = hullPoints.minByOrNull { 
                                Math.sqrt(Math.pow(it.x - originalWidth, 2.0) + Math.pow(it.y - originalHeight, 2.0)) 
                            }!!
                            val bottomLeft = hullPoints.minByOrNull { 
                                Math.sqrt(Math.pow(it.x - 0, 2.0) + Math.pow(it.y - originalHeight, 2.0)) 
                            }!!
                            
                            arrayOf(topLeft, topRight, bottomRight, bottomLeft)
                        } else {
                            // Nếu ít hơn 4 điểm, thêm điểm để đủ 4
                            val extraPoints = arrayOf(
                                Point(0.0, 0.0),
                                Point(originalWidth.toDouble(), 0.0),
                                Point(originalWidth.toDouble(), originalHeight.toDouble()),
                                Point(0.0, originalHeight.toDouble())
                            )
                            (hullPoints + extraPoints).take(4).toTypedArray()
                        }
                        
                        // Sắp xếp điểm theo tọa độ góc
                        val centerX = finalPoints.sumOf { it.x } / finalPoints.size
                        val centerY = finalPoints.sumOf { it.y } / finalPoints.size
                        
                        // Sắp xếp các điểm theo góc phần tư
                        val angles = finalPoints.map { 
                            val angle = Math.atan2(it.y - centerY, it.x - centerX)
                            Pair(it, angle)
                        }.sortedBy { it.second }
                        
                        val sortedPoints = angles.map { it.first }.toTypedArray()
                        
                        // Đảm bảo thứ tự đúng: trên-trái, trên-phải, dưới-phải, dưới-trái
                        val tl = sortedPoints[0]
                        val tr = sortedPoints[1]
                        val br = sortedPoints[2]
                        val bl = sortedPoints[3]
                        
                        return listOf(
                            mapOf("x" to tl.x.toInt(), "y" to tl.y.toInt()),
                            mapOf("x" to tr.x.toInt(), "y" to tr.y.toInt()),
                            mapOf("x" to br.x.toInt(), "y" to br.y.toInt()),
                            mapOf("x" to bl.x.toInt(), "y" to bl.y.toInt())
                        )
                    }
                }
            } else {
                // Xử lý ảnh nhỏ
                // Giảm nhiễu với GaussianBlur
                Imgproc.GaussianBlur(enhanced, enhanced, Size(5.0, 5.0), 0.0)
                
                // Phát hiện cạnh với Canny
                val edges = Mat()
                Imgproc.Canny(enhanced, edges, 50.0, 150.0)
                
                // Áp dụng phép đóng (closing) để kết nối các cạnh đứt đoạn
                val kernel = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(7.0, 7.0))
                val closed = Mat()
                Imgproc.morphologyEx(edges, closed, Imgproc.MORPH_CLOSE, kernel)
                
                // Tìm contours
                val contours = ArrayList<MatOfPoint>()
                val hierarchy = Mat()
                Imgproc.findContours(closed, contours, hierarchy, Imgproc.RETR_EXTERNAL, Imgproc.CHAIN_APPROX_SIMPLE)
                
                // Lọc theo diện tích, chỉ lấy contour lớn nhất
                contours.sortWith { o1, o2 -> 
                    Imgproc.contourArea(o2).compareTo(Imgproc.contourArea(o1))
                }
                
                if (contours.isNotEmpty()) {
                    // Lấy contour lớn nhất
                    val documentContour = contours[0]
                    val documentArea = Imgproc.contourArea(documentContour)
                    val imageArea = originalWidth * originalHeight
                    
                    // Chỉ xử lý nếu contour đủ lớn
                    if (documentArea > imageArea * 0.05) {  // Giảm ngưỡng xuống 5% để bắt được nhiều tài liệu hơn
                        // Xấp xỉ đường viền thành đa giác
                        val epsilon = 0.02 * Imgproc.arcLength(MatOfPoint2f(*documentContour.toArray()), true)
                        val approx = MatOfPoint2f()
                        Imgproc.approxPolyDP(MatOfPoint2f(*documentContour.toArray()), approx, epsilon, true)
                        
                        val points = approx.toArray()
                        
                        // Nếu có 4 điểm hoặc gần 4 điểm
                        if (points.size >= 4 && points.size <= 6) {
                            // Nếu có nhiều hơn 4 điểm, lấy 4 điểm "góc" nhất
                            val finalPoints = if (points.size == 4) {
                                points
                            } else {
                                // Tìm convex hull
                                val hull = MatOfInt()
                                Imgproc.convexHull(MatOfPoint(*points), hull)
                                
                                // Lấy 4 điểm từ convex hull
                                val hullPoints = hull.toArray().map { points[it] }.toTypedArray()
                                
                                // Nếu có nhiều hơn 4 điểm, lấy 4 điểm "góc" nhất
                                if (hullPoints.size > 4) {
                                    // Tính trung tâm
                                    val centerX = hullPoints.sumOf { it.x } / hullPoints.size
                                    val centerY = hullPoints.sumOf { it.y } / hullPoints.size
                                    
                                    // Sắp xếp theo khoảng cách đến trung tâm (giảm dần)
                                    hullPoints.sortedByDescending { 
                                        val dx = it.x - centerX
                                        val dy = it.y - centerY
                                        dx * dx + dy * dy
                                    }.take(4).toTypedArray()
                                } else {
                                    hullPoints
                                }
                            }
                            
                            // Sắp xếp 4 điểm theo góc phần tư
                            // Tính trung tâm
                            val centerX = finalPoints.sumOf { it.x } / finalPoints.size
                            val centerY = finalPoints.sumOf { it.y } / finalPoints.size
                            
                            // Phân loại các điểm theo góc phần tư
                            val tl = finalPoints.minByOrNull { (it.x - centerX) + (it.y - centerY) }!!
                            val br = finalPoints.maxByOrNull { (it.x - centerX) + (it.y - centerY) }!!
                            val tr = finalPoints.minByOrNull { (it.y - centerY) - (it.x - centerX) }!!
                            val bl = finalPoints.minByOrNull { (it.x - centerX) - (it.y - centerY) }!!
                            
                            return listOf(
                                mapOf("x" to tl.x.toInt(), "y" to tl.y.toInt()),
                                mapOf("x" to tr.x.toInt(), "y" to tr.y.toInt()),
                                mapOf("x" to br.x.toInt(), "y" to br.y.toInt()),
                                mapOf("x" to bl.x.toInt(), "y" to bl.y.toInt())
                            )
                        }
                    }
                }
            }
            
            // Nếu không tìm thấy tài liệu, sử dụng giá trị mặc định
            println("No suitable document contour found, using default rectangle")
            val marginX = originalWidth * 0.1
            val marginY = originalHeight * 0.1
            return listOf(
                mapOf("x" to marginX.toInt(), "y" to marginY.toInt()),
                mapOf("x" to (originalWidth - marginX).toInt(), "y" to marginY.toInt()),
                mapOf("x" to (originalWidth - marginX).toInt(), "y" to (originalHeight - marginY).toInt()),
                mapOf("x" to marginX.toInt(), "y" to (originalHeight - marginY).toInt())
            )
        } catch (e: Exception) {
            e.printStackTrace()
            // Giá trị mặc định nếu xảy ra lỗi
            val width = 1000
            val height = 1000
            val marginX = width * 0.1
            val marginY = height * 0.1
            return listOf(
                mapOf("x" to marginX.toInt(), "y" to marginY.toInt()),
                mapOf("x" to (width - marginX).toInt(), "y" to marginY.toInt()),
                mapOf("x" to (width - marginX).toInt(), "y" to (height - marginY).toInt()),
                mapOf("x" to marginX.toInt(), "y" to (height - marginY).toInt())
            )
        }
    }

  private fun cropImage(path: String, points: List<Map<String, Int>>): ByteArray? {
    try {
        val options = BitmapFactory.Options().apply {
            inSampleSize = 1
        }
        val bitmap = BitmapFactory.decodeFile(path, options)
        val src = Mat()
        Utils.bitmapToMat(bitmap, src)
        
        val srcPts = MatOfPoint2f(*points.map {
            Point(it["x"]!!.toDouble(), it["y"]!!.toDouble())
        }.toTypedArray())

        // Tính toán chiều rộng và chiều cao
        val widthTop = distance(points[0], points[1])
        val widthBottom = distance(points[3], points[2])
        val dstWidth = maxOf(widthTop, widthBottom)

        val heightLeft = distance(points[0], points[3])
        val heightRight = distance(points[1], points[2])
        val dstHeight = maxOf(heightLeft, heightRight)

        // Kiểm tra hướng ảnh gốc và điều chỉnh kích thước đầu ra
        val originalLandscape = bitmap.width > bitmap.height
        val resultLandscape = dstWidth > dstHeight
        
        // Nếu hướng ảnh thay đổi, đảo ngược chiều rộng và chiều cao
        val finalWidth: Double
        val finalHeight: Double
        
        if (originalLandscape != resultLandscape) {
            // Đảo kích thước để giữ nguyên hướng ảnh
            finalWidth = dstHeight
            finalHeight = dstWidth
            println("Correcting orientation: swapping dimensions")
        } else {
            finalWidth = dstWidth
            finalHeight = dstHeight
        }

        val dstPts = MatOfPoint2f(
            Point(0.0, 0.0),
            Point(finalWidth, 0.0),
            Point(finalWidth, finalHeight),
            Point(0.0, finalHeight)
        )

        val transform = Imgproc.getPerspectiveTransform(srcPts, dstPts)
        val output = Mat()
        Imgproc.warpPerspective(src, output, transform, Size(finalWidth, finalHeight))

        // Kiểm tra xem ảnh có cần xoay không
        val rotatedOutput = Mat()
        if (originalLandscape != resultLandscape) {
            // Xoay ảnh 90 độ để đảm bảo hướng đúng
            Core.transpose(output, rotatedOutput)
            Core.flip(rotatedOutput, rotatedOutput, 1) // 1 means flipping around y-axis
            println("Applied rotation to maintain original orientation")
        } else {
            output.copyTo(rotatedOutput)
        }

        val outBitmap = Bitmap.createBitmap(rotatedOutput.cols(), rotatedOutput.rows(), Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(rotatedOutput, outBitmap)

        val stream = ByteArrayOutputStream()
        outBitmap.compress(Bitmap.CompressFormat.JPEG, 95, stream)
        
        // Clean up resources
        src.release()
        output.release()
        rotatedOutput.release()
        bitmap.recycle()
        
        return stream.toByteArray()
    } catch (e: Exception) {
        e.printStackTrace()
        return null
    }
}

    private fun distance(p1: Map<String, Int>, p2: Map<String, Int>): Double {
        val dx = (p1["x"]!! - p2["x"]!!).toDouble()
        val dy = (p1["y"]!! - p2["y"]!!).toDouble()
        return Math.sqrt(dx * dx + dy * dy)
    }
}