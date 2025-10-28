import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';

class ImageCropScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const ImageCropScreen({
    Key? key,
    required this.imageBytes,
  }) : super(key: key);

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  final _cropController = CropController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Crop Image'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              _cropController.crop();
            },
          ),
        ],
      ),
      body: Crop(
        image: widget.imageBytes,
        controller: _cropController,
        onCropped: (croppedData) {
          Navigator.of(context).pop(croppedData);
        },
        aspectRatio: 1.0, // Квадратная обрезка - форма не меняется
        initialSize: 0.7, // Начальный размер квадрата - 70% от изображения
        withCircleUi: false, // Квадратная UI
        baseColor: Colors.black.withOpacity(0.8),
        maskColor: Colors.black.withOpacity(0.8),
        cornerDotBuilder: (size, edgeAlignment) => const DotControl(color: Colors.blue),
        interactive: false, // Фотография статична - не двигается
        fixCropRect: false, // Квадрат можно перемещать
      ),
    );
  }
}

