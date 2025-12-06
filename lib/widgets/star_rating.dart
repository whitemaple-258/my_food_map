import 'package:flutter/material.dart';

class StarRating extends StatelessWidget {
  final double rating;
  final Function(double)? onRatingChanged;
  final bool isReadOnly;

  const StarRating({
    super.key,
    required this.rating,
    this.onRatingChanged,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        final starValue = index + 1.0;
        return IconButton(
          iconSize: 32,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: isReadOnly ? null : () => onRatingChanged?.call(starValue),
          icon: Icon(
            rating >= starValue ? Icons.star : Icons.star_border,
            color: Colors.amber,
          ),
        );
      }),
    );
  }
}