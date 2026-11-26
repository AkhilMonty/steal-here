import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/themes/app_colors.dart';
import '../core/themes/app_spacing.dart';
import '../core/themes/app_text_styles.dart';
import '../core/themes/app_decorations.dart';

import '../models/product_review_model.dart';
import '../repositories/product_review_repository.dart';

class ProductReviewsSection extends StatefulWidget {
  const ProductReviewsSection({
    super.key,
    required this.productId,
    this.initiallyOpenReviewForm = false,
  });

  final String productId;
  final bool initiallyOpenReviewForm;

  @override
  State<ProductReviewsSection> createState() => _ProductReviewsSectionState();
}

class _ProductReviewsSectionState extends State<ProductReviewsSection> {
  final ProductReviewRepository _repository = ProductReviewRepository();

  final Color _surface = AppColors.surface;
  final Color _muted = AppColors.textMuted;
  final Color _gold = AppColors.gold;

  List<ProductReviewModel> _reviews = [];

  ProductReviewModel? _myReview;

  bool _isLoading = true;
  bool _canReview = false;
  bool _isSubmitting = false;
  bool _hasHandledInitialReviewRequest = false;

  int _selectedRating = 5;
  int _selectedRatingFilter = 0;

  Map<String, int> _helpfulVoteCounts = {};

  Set<String> _myHelpfulVotes = {};

  final Set<String> _processingHelpfulVotes = {};

  String _sortOption = 'Most Recent';

  final TextEditingController _reviewController = TextEditingController();

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _showReportReviewDialog(String reviewId) async {
    const reasons = {
      'spam': 'Spam or promotional content',
      'offensive': 'Offensive or abusive language',
      'fake_information': 'Fake or misleading information',
      'irrelevant': 'Irrelevant content',
      'other': 'Other',
    };

    String selectedReason = 'spam';
    final detailsController = TextEditingController();
    bool isSubmitting = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: const Color(0xFF171722),
                title: const Text(
                  'Report Review',
                  style: TextStyle(color: Colors.white),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Why are you reporting this review?',
                        style: TextStyle(color: Color(0xFF9A9AAF)),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedReason,
                        dropdownColor: const Color(0xFF171722),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: reasons.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(
                              entry.value,
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }).toList(),
                        onChanged: isSubmitting
                            ? null
                            : (value) {
                                if (value != null) {
                                  setDialogState(() {
                                    selectedReason = value;
                                  });
                                }
                              },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: detailsController,
                        enabled: !isSubmitting,
                        maxLines: 4,
                        maxLength: 1000,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Additional details (optional)',
                          hintText: 'Tell us more about the issue...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setDialogState(() {
                              isSubmitting = true;
                            });

                            try {
                              await ProductReviewRepository()
                                  .submitReviewReport(
                                    reviewId: reviewId,
                                    reason: selectedReason,
                                    details: detailsController.text,
                                  );

                              if (!dialogContext.mounted) return;

                              Navigator.pop(dialogContext);

                              if (!mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Thank you. Your report has been submitted.',
                                  ),
                                ),
                              );
                            } catch (error) {
                              if (!dialogContext.mounted) return;

                              setDialogState(() {
                                isSubmitting = false;
                              });

                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Unable to submit report: $error',
                                  ),
                                ),
                              );
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit Report'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      detailsController.dispose();
    }
  }

  Future<void> _loadReviews() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final reviews = await _repository.getReviews(widget.productId);

      ProductReviewModel? myReview;
      var canReview = false;

      if (_currentUserId != null) {
        myReview = await _repository.getMyReview(widget.productId);
        canReview = await _repository.canReviewProduct(widget.productId);
      }

      final reviewIds = reviews.map((review) => review.id).toList();

      Map<String, int> helpfulVoteCounts = {};
      Set<String> myHelpfulVotes = {};

      if (reviewIds.isNotEmpty) {
        try {
          helpfulVoteCounts = await _repository.getHelpfulVoteCounts(reviewIds);

          myHelpfulVotes = await _repository.getMyHelpfulVotes(reviewIds);
        } catch (_) {
          // Keep reviews visible even if helpful votes cannot be loaded.
        }
      }

      if (!mounted) return;

      setState(() {
        _reviews = reviews;
        _myReview = myReview;
        _canReview = canReview;
        _helpfulVoteCounts = helpfulVoteCounts;
        _myHelpfulVotes = myHelpfulVotes;
        _isLoading = false;
      });

      // Automatically open the review form when requested by navigation.
      if (widget.initiallyOpenReviewForm && !_hasHandledInitialReviewRequest) {
        _hasHandledInitialReviewRequest = true;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          _openReviewForm();
        });
      }
    } catch (error) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to load reviews: $error')));
    }
  }

  Future<void> _openReviewForm() async {
    if (!_canReview && _myReview == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You can review this product after it has been delivered.',
          ),
        ),
      );
      return;
    }

    _selectedRating = _myReview?.rating ?? 5;
    _reviewController.text = _myReview?.reviewText ?? '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                24,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _myReview == null ? 'Write a Review' : 'Edit Your Review',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Share your experience with this product.',
                      style: TextStyle(color: _muted),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Your Rating',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: List.generate(5, (index) {
                        final star = index + 1;

                        return IconButton(
                          onPressed: () {
                            setModalState(() {
                              _selectedRating = star;
                            });
                          },
                          icon: Icon(
                            star <= _selectedRating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: _gold,
                            size: 34,
                          ),
                        );
                      }),
                    ),
                    Text(
                      '$_selectedRating out of 5 stars',
                      style: TextStyle(color: _gold),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _reviewController,
                      maxLines: 5,
                      maxLength: 2000,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Write your review...',
                        hintStyle: TextStyle(color: _muted),
                        filled: true,
                        fillColor: const Color(0xFF0B0B12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => _submitReview(Navigator.of(context)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Submit Review',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitReview(NavigatorState navigator) async {
    final reviewText = _reviewController.text.trim();

    if (reviewText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write your review first.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _repository.saveReview(
        productId: widget.productId,
        rating: _selectedRating,
        reviewText: reviewText,
      );

      if (!mounted) return;

      navigator.pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your review has been saved successfully.'),
        ),
      );

      await _loadReviews();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to save review: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _deleteReview() async {
    if (_myReview == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _surface,
          title: const Text(
            'Delete Review?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to delete your review?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _repository.deleteReview(_myReview!.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your review has been deleted.')),
      );

      await _loadReviews();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete review: $error')),
      );
    }
  }

  List<ProductReviewModel> get _displayedReviews {
    final filteredReviews = _reviews.where((review) {
      return _selectedRatingFilter == 0 ||
          review.rating == _selectedRatingFilter;
    }).toList();

    switch (_sortOption) {
      case 'Highest Rating':
        filteredReviews.sort((a, b) => b.rating.compareTo(a.rating));
        break;

      case 'Lowest Rating':
        filteredReviews.sort((a, b) => a.rating.compareTo(b.rating));
        break;

      case 'Most Recent':
      default:
        filteredReviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    return filteredReviews;
  }

  Widget _buildReviewFilters() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sort Reviews',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _sortOption,
            dropdownColor: AppColors.surface,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                borderSide: BorderSide.none,
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: 'Most Recent',
                child: Text('Most Recent'),
              ),
              DropdownMenuItem(
                value: 'Highest Rating',
                child: Text('Highest Rating'),
              ),
              DropdownMenuItem(
                value: 'Lowest Rating',
                child: Text('Lowest Rating'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                _sortOption = value;
              });
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Filter by Rating',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (int rating = 0; rating <= 5; rating++)
                ChoiceChip(
                  label: Text(rating == 0 ? 'All' : '$rating ★'),
                  selected: _selectedRatingFilter == rating,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.background,
                  labelStyle: AppTextStyles.labelMedium.copyWith(
                    color: _selectedRatingFilter == rating
                        ? Colors.white
                        : AppColors.textMuted,
                  ),
                  side: BorderSide(
                    color: _selectedRatingFilter == rating
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                  onSelected: (_) {
                    setState(() {
                      _selectedRatingFilter = rating;
                    });
                  },
                ),
            ],
          ),
          if (_selectedRatingFilter != 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _selectedRatingFilter = 0;
                  });
                },
                child: Text(
                  'Clear Rating Filter',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingDistribution() {
    final totalReviews = _reviews.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rating Distribution',
            style: AppTextStyles.headingSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...List.generate(5, (index) {
            final rating = 5 - index;

            final ratingCount = _reviews
                .where((review) => review.rating == rating)
                .length;

            final percentage = totalReviews == 0
                ? 0.0
                : ratingCount / totalReviews;

            final isSelected = _selectedRatingFilter == rating;

            return InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              onTap: () {
                setState(() {
                  _selectedRatingFilter = isSelected ? 0 : rating;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    SizedBox(
                      width: 42,
                      child: Text(
                        '$rating ★',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: isSelected
                              ? AppColors.gold
                              : AppColors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusCircular,
                        ),
                        child: LinearProgressIndicator(
                          value: percentage,
                          minHeight: 9,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.gold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 28,
                      child: Text(
                        '$ratingCount',
                        textAlign: TextAlign.end,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStars(int rating) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          color: _gold,
          size: 17,
        );
      }),
    );
  }

  Future<void> _toggleHelpfulVote(String reviewId) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to mark reviews as helpful.'),
        ),
      );
      return;
    }

    if (_processingHelpfulVotes.contains(reviewId)) return;

    setState(() {
      _processingHelpfulVotes.add(reviewId);
    });

    try {
      await _repository.toggleHelpfulVote(reviewId);

      if (!mounted) return;

      final alreadyVoted = _myHelpfulVotes.contains(reviewId);

      setState(() {
        if (alreadyVoted) {
          _myHelpfulVotes.remove(reviewId);

          final currentCount = _helpfulVoteCounts[reviewId] ?? 0;

          _helpfulVoteCounts[reviewId] = currentCount > 0
              ? currentCount - 1
              : 0;
        } else {
          _myHelpfulVotes.add(reviewId);

          _helpfulVoteCounts[reviewId] =
              (_helpfulVoteCounts[reviewId] ?? 0) + 1;
        }
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update helpful vote: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingHelpfulVotes.remove(reviewId);
        });
      }
    }
  }

  Widget _buildReviewCard(ProductReviewModel review) {
    final isMyReview = review.userId == _currentUserId;
    final hasVoted = _myHelpfulVotes.contains(review.id);
    final isProcessing = _processingHelpfulVotes.contains(review.id);
    final helpfulCount = _helpfulVoteCounts[review.id] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card.copyWith(
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: const Icon(
                  Icons.person_outline,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMyReview ? 'Your Review' : 'Customer Review',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (review.isVerifiedPurchase) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusCircular,
                          ),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified,
                              color: Colors.greenAccent,
                              size: 13,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Verified Purchase',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: AppColors.surface,
                icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
                onSelected: (value) {
                  if (value == 'edit') {
                    _openReviewForm();
                  } else if (value == 'delete') {
                    _deleteReview();
                  } else if (value == 'report') {
                    _showReportReviewDialog(review.id);
                  }
                },
                itemBuilder: (context) {
                  if (isMyReview) {
                    return const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(
                          'Edit review',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete review',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ];
                  }

                  return const [
                    PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(
                            Icons.flag_outlined,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Report review',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildStars(review.rating),
          const SizedBox(height: AppSpacing.md),
          Text(
            review.reviewText,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Reviewed on ${review.createdAt.toLocal().toString().split(' ').first}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              if (!isMyReview)
                TextButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () => _toggleHelpfulVote(review.id),
                  icon: isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : Icon(
                          hasVoted ? Icons.thumb_up : Icons.thumb_up_outlined,
                          size: 17,
                          color: hasVoted
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                  label: Text(
                    helpfulCount == 0 ? 'Helpful' : 'Helpful ($helpfulCount)',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: hasVoted ? AppColors.primary : AppColors.textMuted,
                      fontWeight: hasVoted
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedReviews = _displayedReviews;

    final averageRating = _reviews.isEmpty
        ? 0.0
        : _reviews.fold<int>(0, (total, review) => total + review.rating) /
              _reviews.length;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer Reviews',
            style: AppTextStyles.headingMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: AppDecorations.premiumCard,
              child: Row(
                children: [
                  Column(
                    children: [
                      Text(
                        averageRating.toStringAsFixed(1),
                        style: AppTextStyles.headingMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 34,
                        ),
                      ),
                      _buildStars(averageRating.round()),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${_reviews.length} reviews',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (_canReview || _myReview != null)
                    Flexible(
                      child: ElevatedButton.icon(
                        onPressed: _openReviewForm,
                        icon: const Icon(Icons.rate_review_outlined, size: 18),
                        label: Text(
                          _myReview == null ? 'Write Review' : 'Edit Review',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.md,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMedium,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_reviews.isNotEmpty) ...[
              _buildRatingDistribution(),
              const SizedBox(height: AppSpacing.lg),
              _buildReviewFilters(),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (_reviews.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xxl),
                decoration: AppDecorations.card,
                child: Column(
                  children: [
                    Icon(
                      Icons.rate_review_outlined,
                      color: AppColors.textMuted.withValues(alpha: 0.7),
                      size: 38,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No reviews yet',
                      style: AppTextStyles.headingSmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Be the first to share your experience!',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              )
            else if (displayedReviews.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: AppDecorations.card,
                child: Text(
                  'No reviews found for this rating.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              )
            else
              ...displayedReviews.map(_buildReviewCard),
          ],
        ],
      ),
    );
  }
}
