import 'product_model.dart';

enum RecommendationType { personalized, popular }

class ProductRecommendationModel {
  final ProductModel product;
  final String reason;
  final String reasonLabel;
  final RecommendationType type;

  const ProductRecommendationModel({
    required this.product,
    required this.reason,
    required this.reasonLabel,
    this.type = RecommendationType.personalized,
  });

  bool get isPersonalized => type == RecommendationType.personalized;

  bool get isPopular => type == RecommendationType.popular;
}
