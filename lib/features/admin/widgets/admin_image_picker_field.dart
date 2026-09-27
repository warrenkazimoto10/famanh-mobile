import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/api_client.dart';
import '../../../theme/adiake_colors.dart';

class AdminImagePickerField extends StatefulWidget {
  const AdminImagePickerField({
    super.key,
    this.initialUrl,
    required this.label,
    required this.onUploaded,
    this.height = 160,
  });

  final String? initialUrl;
  final String label;
  final ValueChanged<String> onUploaded;
  final double height;

  @override
  State<AdminImagePickerField> createState() => _AdminImagePickerFieldState();
}

class _AdminImagePickerFieldState extends State<AdminImagePickerField> {
  bool _uploading = false;
  Uint8List? _previewBytes;
  String? _currentUrl;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;
  }

  Future<void> _pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() { _previewBytes = bytes; _uploading = true; });
    try {
      final url = await AdminApiExtra.adminUploadPhoto(file);
      if (!mounted) return;
      setState(() { _currentUrl = url; _uploading = false; });
      widget.onUploaded(url);
    } catch (e) {
      if (!mounted) return;
      setState(() { _uploading = false; _previewBytes = null; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: AdiakeColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 8),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFF3E5F5), child: Icon(Icons.photo_library_rounded, color: Color(0xFF6A1B9A))),
            title: const Text('Choisir depuis la galerie', style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () { Navigator.pop(ctx); _pick(ImageSource.gallery); },
          ),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFE3F2FD), child: Icon(Icons.camera_alt_rounded, color: Color(0xFF1565C0))),
            title: const Text('Prendre une photo', style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () { Navigator.pop(ctx); _pick(ImageSource.camera); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _previewBytes != null || (_currentUrl?.isNotEmpty ?? false);
    return GestureDetector(
      onTap: _uploading ? null : _showSourcePicker,
      child: Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasImage ? AdiakeColors.primaryContainer.withValues(alpha: 0.40) : const Color(0xFFDDDDDD),
            width: hasImage ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: _uploading
            ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(strokeWidth: 2.5),
                SizedBox(height: 10),
                Text('Upload en cours…', style: TextStyle(fontSize: 12, color: AdiakeColors.onSurfaceVariant)),
              ]))
            : hasImage
                ? Stack(fit: StackFit.expand, children: [
                    _previewBytes != null
                        ? Image.memory(_previewBytes!, fit: BoxFit.cover)
                        : Image.network(_currentUrl!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder()),
                    Positioned(
                      right: 8, bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.edit_rounded, size: 13, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Changer', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  ])
                : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.add_photo_alternate_rounded, size: 38, color: AdiakeColors.outline),
    const SizedBox(height: 8),
    Text(widget.label, style: const TextStyle(fontSize: 13, color: AdiakeColors.onSurfaceVariant, fontWeight: FontWeight.w600)),
    const SizedBox(height: 3),
    const Text('Galerie ou appareil photo', style: TextStyle(fontSize: 11, color: AdiakeColors.outline)),
  ]);
}
