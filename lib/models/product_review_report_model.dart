class ProductReviewReportModel {
  final String id;
  final String reviewId;
  final String reporterUserId;
  final String reason;
  final String? details;
  final String status;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  const ProductReviewReportModel({
    required this.id,
    required this.reviewId,
    required this.reporterUserId,
    required this.reason,
    this.details,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
  });

  factory ProductReviewReportModel.fromJson(Map<String, dynamic> json) {
    return ProductReviewReportModel(
      id: json['id'] as String,
      reviewId: json['review_id'] as String,
      reporterUserId: json['reporter_user_id'] as String,
      reason: json['reason'] as String,
      details: json['details'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      reviewedAt: json['reviewed_at'] == null
          ? null
          : DateTime.parse(json['reviewed_at'] as String),
    );
  }
}
