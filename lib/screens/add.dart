import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class Add extends StatefulWidget {
  @override
  _AddState createState() => _AddState();
}

class _AddState extends State<Add> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController typeController = TextEditingController();
  final TextEditingController conditionController = TextEditingController();
  final TextEditingController brandController = TextEditingController();
  final TextEditingController specificationsController = TextEditingController();

  File? _image;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: _image == null
                  ? Icon(Icons.camera_alt, size: 80, color: Colors.grey)
                  : Image.file(_image!, width: 100, height: 100, fit: BoxFit.cover),
            ),
            SizedBox(height: 20),
            TextField(controller: nameController, decoration: InputDecoration(labelText: "Name")),
            TextField(controller: typeController, decoration: InputDecoration(labelText: "Type")),
            TextField(controller: conditionController, decoration: InputDecoration(labelText: "New or Old")),
            TextField(controller: brandController, decoration: InputDecoration(labelText: "Brand")),
            TextField(controller: specificationsController, decoration: InputDecoration(labelText: "Specifications")),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Handle post action here including the image if needed
              },
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 45)),
              child: Text("Post"),
            ),
          ],
        ),
      ),
    );
  }
}
