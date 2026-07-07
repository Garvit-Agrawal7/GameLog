import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

typedef RatingChanged = void Function(int? rating);

class RatingPicker extends StatefulWidget {
  const RatingPicker({
    required this.selectedRating,
    required this.onRatingChanged,
    this.showLabels = true,
    this.compact = false,
    super.key,
  });

  final int? selectedRating;
  final RatingChanged onRatingChanged;
  final bool showLabels;
  final bool compact;

  @override
  State<RatingPicker> createState() => _RatingPickerState();
}

class _RatingPickerState extends State<RatingPicker> {
  static const List<int?> _ratings = [null, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1];
  static const double _itemWidth = 48;
  static const double _selectorSize = 48;
  static const double _height = 88;
  static const double _compactItemWidth = 34;
  static const double _compactSelectorSize = 34;
  static const double _compactHeight = 58;

  PageController? _pageController;
  double? _viewportFraction;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    final initialIndex = _ratings.indexOf(widget.selectedRating);
    _selectedIndex = initialIndex < 0 ? 0 : initialIndex;
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  PageController _controllerForWidth(double width) {
    final itemWidth = widget.compact ? _compactItemWidth : _itemWidth;
    final viewportFraction = (itemWidth / width).clamp(0.01, 1.0);
    if (_pageController == null || _viewportFraction != viewportFraction) {
      final initialIndex = _ratings.indexOf(widget.selectedRating);
      _pageController?.dispose();
      _viewportFraction = viewportFraction;
      _pageController = PageController(
        initialPage: initialIndex < 0 ? 0 : initialIndex,
        viewportFraction: viewportFraction,
      );
    }
    return _pageController!;
  }

  String _ratingLabel(int? rating) {
    switch (rating) {
      case 10:
        return 'Masterpiece';
      case 9:
        return 'Great';
      case 8:
        return 'Very Good';
      case 7:
        return 'Good';
      case 6:
        return 'Fine';
      case 5:
        return 'Average';
      case 4:
        return 'Bad';
      case 3:
        return 'Very Bad';
      case 2:
        return 'Horrible';
      case 1:
        return 'Appalling';
      default:
        return 'Not Yet Scored';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.compact ? _compactHeight : _height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pageController = _controllerForWidth(constraints.maxWidth);
          final itemWidth = widget.compact ? _compactItemWidth : _itemWidth;
          final selectorSize = widget.compact ? _compactSelectorSize : _selectorSize;

          return Stack(
            children: [
              if (widget.showLabels)
                Align(
                  alignment: Alignment.topCenter,
                  child: ClipPath(
                    clipper: const RatingLabelClipper(),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 3, 12, 13),
                      color: AppColors.accentPurple,
                      child: Text(
                        _ratingLabel(_ratings[_selectedIndex]),
                        style: AppTextStyles.label.copyWith(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: selectorSize,
                  height: selectorSize,
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.accentPurple, width: 2),
                    borderRadius: BorderRadius.circular(widget.compact ? 7 : 8),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  top: widget.showLabels ? (widget.compact ? 22 : 34) : 8,
                ),
                child: PageView.builder(
                  controller: pageController,
                  itemCount: _ratings.length,
                  onPageChanged: (index) {
                    setState(() => _selectedIndex = index);
                    widget.onRatingChanged(_ratings[index]);
                  },
                  itemBuilder: (context, index) {
                    final rating = _ratings[index];
                    final displayValue = rating == null ? '-' : rating.toString();

                    return Center(
                      child: SizedBox(
                        width: itemWidth,
                        child: Center(
                          child: Text(
                            displayValue,
                            style: AppTextStyles.label.copyWith(
                              fontSize: widget.compact ? 14 : 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentPurple,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class RatingLabelClipper extends CustomClipper<Path> {
  const RatingLabelClipper();

  @override
  Path getClip(Size size) {
    const arrowWidth = 16.0;
    const arrowHeight = 10.0;
    const radius = 4.0;
    final arrowLeft = (size.width - arrowWidth) / 2;
    final arrowRight = arrowLeft + arrowWidth;
    final bodyBottom = size.height - arrowHeight;

    return Path()
      ..moveTo(radius, 0)
      ..lineTo(size.width - radius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, radius)
      ..lineTo(size.width, bodyBottom - radius)
      ..quadraticBezierTo(size.width, bodyBottom, size.width - radius, bodyBottom)
      ..lineTo(arrowRight, bodyBottom)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(arrowLeft, bodyBottom)
      ..lineTo(radius, bodyBottom)
      ..quadraticBezierTo(0, bodyBottom, 0, bodyBottom - radius)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant RatingLabelClipper oldClipper) => false;
}

