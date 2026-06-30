import 'package:flutter/material.dart';

class PhotoGallery extends StatefulWidget {
  const PhotoGallery({
    super.key,
    required this.photos,
    required this.fallbackAsset,
  });
  final List<String> photos;
  final String fallbackAsset;

  @override
  State<PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> get _images =>
      widget.photos.isEmpty ? [widget.fallbackAsset] : widget.photos;

  @override
  Widget build(BuildContext context) {
    final images = _images;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: PageView.builder(
            controller: _controller,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => Semantics(
              label: 'Photo ${i + 1} of ${images.length}',
              image: true,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  images[i],
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: Colors.grey[300],
                    child: const Center(child: Icon(Icons.image, size: 48)),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < images.length; i++)
                Padding(
                  key: ValueKey('gallery-dot-$i'),
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Icon(
                    Icons.circle,
                    size: 8,
                    color: i == _index
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[400],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
