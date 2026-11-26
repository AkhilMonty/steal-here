class ProductQuestionModel {
  final String id;
  final String productId;
  final String? userId;
  final String question;
  final String? answer;
  final String? answeredBy;
  final DateTime? answeredAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isOwner;

  const ProductQuestionModel({
    required this.id,
    required this.productId,
    this.userId,
    required this.question,
    this.answer,
    this.answeredBy,
    this.answeredAt,
    required this.createdAt,
    required this.updatedAt,
    this.isOwner = false,
  });

  bool get isAnswered => answer != null && answer!.trim().isNotEmpty;

  factory ProductQuestionModel.fromJson(Map<String, dynamic> json) {
    return ProductQuestionModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      userId: json['user_id'] as String?,
      question: json['question'] as String,
      answer: json['answer'] as String?,
      answeredBy: json['answered_by'] as String?,
      answeredAt: json['answered_at'] != null
          ? DateTime.parse(json['answered_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isOwner: json['is_owner'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'user_id': userId,
      'question': question,
      'answer': answer,
      'answered_by': answeredBy,
      'answered_at': answeredAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_owner': isOwner,
    };
  }

  ProductQuestionModel copyWith({
    String? question,
    String? answer,
    String? answeredBy,
    DateTime? answeredAt,
    DateTime? updatedAt,
    bool? isOwner,
  }) {
    return ProductQuestionModel(
      id: id,
      productId: productId,
      userId: userId,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      answeredBy: answeredBy ?? this.answeredBy,
      answeredAt: answeredAt ?? this.answeredAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isOwner: isOwner ?? this.isOwner,
    );
  }
}
