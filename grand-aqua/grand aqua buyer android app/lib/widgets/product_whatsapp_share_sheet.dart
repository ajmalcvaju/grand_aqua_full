import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ProductWhatsappShareSheet extends StatefulWidget {
  final Map<String, dynamic> product;
  final String backendBaseUrl;

  const ProductWhatsappShareSheet({
    super.key,
    required this.product,
    required this.backendBaseUrl,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> product,
    required String backendBaseUrl,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProductWhatsappShareSheet(
        product: product,
        backendBaseUrl: backendBaseUrl,
      ),
    );
  }

  @override
  State<ProductWhatsappShareSheet> createState() => _ProductWhatsappShareSheetState();
}

class _ProductWhatsappShareSheetState extends State<ProductWhatsappShareSheet> {
  final TextEditingController _customerPhoneCtrl = TextEditingController();
  final TextEditingController _customPriceCtrl = TextEditingController();
  bool _includePrice = true;
  bool _isDownloading = false;
  String _downloadStatus = '';

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    final price = (p['applicablePrice'] ?? p['pricing']?['priceCustomer'] ?? 0) as num;
    _customPriceCtrl.text = price > 0 ? price.toStringAsFixed(0) : '';
  }

  @override
  void dispose() {
    _customerPhoneCtrl.dispose();
    _customPriceCtrl.dispose();
    super.dispose();
  }

  String _resolveUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final cleanBase = widget.backendBaseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
    final cleanPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$cleanBase$cleanPath';
  }

  List<String> _getImageUrls() {
    final p = widget.product;
    final List<String> urls = [];

    // 1. Direct imageUrl field
    if (p['imageUrl'] != null && p['imageUrl'].toString().trim().isNotEmpty) {
      urls.add(_resolveUrl(p['imageUrl'].toString()));
    }

    // 2. Media array
    final mediaList = (p['media'] as List<dynamic>?) ?? [];
    for (var m in mediaList) {
      if (m is Map && (m['mediaType'] == 'IMAGE' || m['mediaType'] == null)) {
        final u = _resolveUrl(m['url']?.toString());
        if (u.isNotEmpty && !urls.contains(u)) {
          urls.add(u);
        }
      }
    }

    return urls;
  }

  List<String> _getVideoUrls() {
    final p = widget.product;
    final List<String> urls = [];

    // 1. Direct videoUrl field
    if (p['videoUrl'] != null && p['videoUrl'].toString().trim().isNotEmpty) {
      urls.add(_resolveUrl(p['videoUrl'].toString()));
    }

    // 2. Media array
    final mediaList = (p['media'] as List<dynamic>?) ?? [];
    for (var m in mediaList) {
      if (m is Map && m['mediaType'] == 'VIDEO') {
        final u = _resolveUrl(m['url']?.toString());
        if (u.isNotEmpty && !urls.contains(u)) {
          urls.add(u);
        }
      }
    }

    return urls;
  }

  String _buildShareMessage({bool forVideo = false}) {
    final p = widget.product;
    final name = p['name'] ?? 'Grand Aqua Water Purifier';
    final brand = p['brand'] ?? 'Grand Aqua';
    final modelNumber = p['modelNumber'] ?? p['sku'] ?? '';
    final shortDesc = p['shortDescription'] ?? '';
    final warranty = p['warrantyDetails'] ?? '1 Year Comprehensive Manufacturer Warranty';

    final sb = StringBuffer();
    sb.writeln('💧 *Grand Aqua Pure & Healthy Water Purifier*');
    sb.writeln('━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('✨ *Product:* $name');
    sb.writeln('🏷️ *Brand:* $brand');
    if (modelNumber.toString().isNotEmpty) {
      sb.writeln('🆔 *Model / SKU:* $modelNumber');
    }

    if (_includePrice && _customPriceCtrl.text.trim().isNotEmpty) {
      sb.writeln('💰 *Special Price:* ₹${_customPriceCtrl.text.trim()} (Taxes Included)');
    }

    sb.writeln('━━━━━━━━━━━━━━━━━━━━');

    if (shortDesc.toString().isNotEmpty) {
      sb.writeln('📝 *Highlights:*');
      sb.writeln('$shortDesc');
      sb.writeln('');
    }

    // Technical specifications highlights
    final specs = p['technicalSpecifications'];
    if (specs is Map && specs.isNotEmpty) {
      sb.writeln('⚙️ *Key Specifications:*');
      specs.forEach((k, v) {
        if (v != null && v.toString().trim().isNotEmpty) {
          sb.writeln('• $k: $v');
        }
      });
      sb.writeln('');
    }

    if (warranty.toString().isNotEmpty) {
      sb.writeln('🛡️ *Warranty:* $warranty');
    }

    final videoUrls = _getVideoUrls();
    if (forVideo && videoUrls.isNotEmpty) {
      sb.writeln('');
      sb.writeln('🎥 *Watch Product Demo Video:*');
      sb.writeln(videoUrls.first);
    }

    sb.writeln('');
    sb.writeln('📞 *Contact us now for orders, live demo & doorstep installation!*');
    sb.writeln('Grand Aqua — Pure | Safe | Healthy');

    return sb.toString();
  }

  Future<File?> _downloadMediaLocally(String url, String extension) async {
    try {
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final fileName = 'ga_share_${DateTime.now().millisecondsSinceEpoch}$extension';
      final savePath = '${tempDir.path}/$fileName';

      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() {
              _downloadStatus = 'Downloading: ${(received / total * 100).toStringAsFixed(0)}%';
            });
          }
        },
      );

      final file = File(savePath);
      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (e) {
      debugPrint('Error downloading media for share: $e');
      return null;
    }
  }

  Future<void> _sharePhotoViaWhatsapp() async {
    final images = _getImageUrls();
    final message = _buildShareMessage(forVideo: false);

    if (images.isEmpty) {
      // Share as text message directly
      await _shareTextOnly(message);
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadStatus = 'Preparing product photo...';
    });

    try {
      final imgUrl = images.first;
      String ext = '.jpg';
      if (imgUrl.toLowerCase().contains('.png')) ext = '.png';
      if (imgUrl.toLowerCase().contains('.webp')) ext = '.webp';

      final file = await _downloadMediaLocally(imgUrl, ext);
      if (!mounted) return;

      setState(() => _isDownloading = false);

      if (file != null) {
        // Share via SharePlus which passes directly to WhatsApp and other apps
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: message,
            subject: '${widget.product['name']} — Grand Aqua',
          ),
        );
      } else {
        // Fallback: share text with image link
        await _shareTextOnly('$message\n\n🖼️ Product Image: $imgUrl');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sharing note: $e')),
        );
      }
    }
  }

  Future<void> _shareVideoViaWhatsapp() async {
    final videos = _getVideoUrls();
    final message = _buildShareMessage(forVideo: true);

    if (videos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No demo video uploaded for this product yet. Sharing product photo instead!'),
          backgroundColor: Color(0xFF0284C7),
        ),
      );
      await _sharePhotoViaWhatsapp();
      return;
    }

    final videoUrl = videos.first;
    final isDirectFile = videoUrl.endsWith('.mp4') || videoUrl.endsWith('.mov') || videoUrl.contains('/uploads/');

    if (isDirectFile) {
      setState(() {
        _isDownloading = true;
        _downloadStatus = 'Preparing demo video file...';
      });

      try {
        final file = await _downloadMediaLocally(videoUrl, '.mp4');
        if (!mounted) return;
        setState(() => _isDownloading = false);

        if (file != null) {
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(file.path)],
              text: message,
              subject: '${widget.product['name']} Video Demo — Grand Aqua',
            ),
          );
          return;
        }
      } catch (e) {
        debugPrint('Direct video share fallback: $e');
      }
    }

    if (mounted) setState(() => _isDownloading = false);
    // Share video link formatted message
    await _shareTextOnly(message);
  }

  Future<void> _shareAllPhotos() async {
    final images = _getImageUrls();
    final message = _buildShareMessage(forVideo: false);

    if (images.isEmpty) {
      await _shareTextOnly(message);
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadStatus = 'Preparing ${images.length} product photos...';
    });

    try {
      final List<XFile> xfiles = [];
      for (int i = 0; i < images.length; i++) {
        final imgUrl = images[i];
        String ext = '.jpg';
        if (imgUrl.toLowerCase().contains('.png')) ext = '.png';
        if (imgUrl.toLowerCase().contains('.webp')) ext = '.webp';

        final f = await _downloadMediaLocally(imgUrl, ext);
        if (f != null) {
          xfiles.add(XFile(f.path));
        }
      }

      if (!mounted) return;
      setState(() => _isDownloading = false);

      if (xfiles.isNotEmpty) {
        await SharePlus.instance.share(
          ShareParams(
            files: xfiles,
            text: message,
            subject: '${widget.product['name']} Photos — Grand Aqua',
          ),
        );
      } else {
        await _shareTextOnly(message);
      }
    } catch (e) {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _shareDirectToWhatsappNumber() async {
    final rawPhone = _customerPhoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
    if (rawPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter customer phone number')),
      );
      return;
    }

    final formattedPhone = rawPhone.length == 10 ? '91$rawPhone' : rawPhone;
    final message = _buildShareMessage(forVideo: false);

    // If there is an image, append image link
    final images = _getImageUrls();
    final fullText = images.isNotEmpty ? '$message\n\n🖼️ Product Photo: ${images.first}' : message;

    final whatsappSchemeUrl = Uri.parse('whatsapp://send?phone=$formattedPhone&text=${Uri.encodeComponent(fullText)}');
    final webUrl = Uri.parse('https://api.whatsapp.com/send?phone=$formattedPhone&text=${Uri.encodeComponent(fullText)}');

    try {
      if (await canLaunchUrl(whatsappSchemeUrl)) {
        await launchUrl(whatsappSchemeUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open WhatsApp: $e')),
        );
      }
    }
  }

  Future<void> _shareTextOnly(String text) async {
    final whatsappSchemeUrl = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
    final webUrl = Uri.parse('https://api.whatsapp.com/send?text=${Uri.encodeComponent(text)}');

    try {
      if (await canLaunchUrl(whatsappSchemeUrl)) {
        await launchUrl(whatsappSchemeUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        await SharePlus.instance.share(ShareParams(text: text));
      }
    } catch (_) {
      await SharePlus.instance.share(ShareParams(text: text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final name = p['name'] ?? 'Product';
    final brand = p['brand'] ?? 'Grand Aqua';
    final images = _getImageUrls();
    final videos = _getVideoUrls();
    final primaryImg = images.isNotEmpty ? images.first : '';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header with WhatsApp Branding
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF25D366), // WhatsApp Green
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.share, color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Share via WhatsApp',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Send photos, demo videos & specs to customers',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Product Mini Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 54,
                      height: 54,
                      color: Colors.white,
                      child: primaryImg.isNotEmpty
                          ? Image.network(
                              primaryImg,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Icon(Icons.water_drop, color: Color(0xFF0284C7)),
                            )
                          : const Icon(Icons.water_drop, color: Color(0xFF0284C7)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$brand • ${images.length} Photos ${videos.isNotEmpty ? "• 🎬 Video available" : ""}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Pricing Toggle & Customization
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Include Price in Message',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Switch(
                        value: _includePrice,
                        activeThumbColor: const Color(0xFF25D366),
                        onChanged: (v) => setState(() => _includePrice = v),
                      ),
                    ],
                  ),
                  if (_includePrice)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: TextField(
                        controller: _customPriceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Customer Offer Price (₹)',
                          hintText: 'Enter retail selling price for your customer',
                          prefixText: '₹ ',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            if (_isDownloading) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF25D366)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _downloadStatus.isNotEmpty ? _downloadStatus : 'Processing media...',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Text(
              'SHARE OPTIONS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 10),

            // Button 1: Share Product Photo (Primary Action)
            ElevatedButton.icon(
              onPressed: _isDownloading ? null : _sharePhotoViaWhatsapp,
              icon: const Icon(Icons.photo_camera, size: 20),
              label: Text(
                images.isNotEmpty ? 'Share Product Photo & Specs' : 'Share Product Details',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),

            // Button 2: Share Product Video
            OutlinedButton.icon(
              onPressed: _isDownloading ? null : _shareVideoViaWhatsapp,
              icon: Icon(
                Icons.play_circle_fill,
                color: videos.isNotEmpty ? const Color(0xFFDC2626) : Colors.grey,
                size: 20,
              ),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Share Product Demo Video', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  if (videos.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('READY', style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('VIDEO LINK', style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            if (images.length > 1) ...[
              const SizedBox(height: 10),
              // Button 3: Share All Photos
              OutlinedButton.icon(
                onPressed: _isDownloading ? null : _shareAllPhotos,
                icon: const Icon(Icons.photo_library_outlined, size: 20, color: Color(0xFF0284C7)),
                label: Text('Share All ${images.length} Photos (Gallery)', style: const TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0284C7),
                  side: const BorderSide(color: Color(0xFFBAE6FD)),
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Direct WhatsApp To Specific Phone Number
            const Text(
              'OR SEND DIRECT TO A CUSTOMER NUMBER',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customerPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Customer Mobile',
                      hintText: 'e.g. 9876543210',
                      prefixText: '+91 ',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _shareDirectToWhatsappNumber,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(60, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Send', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _buildShareMessage()));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Product description copied to clipboard!')),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy Marketing Text to Clipboard'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
