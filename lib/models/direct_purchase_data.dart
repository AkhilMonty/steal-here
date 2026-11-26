import 'product_model.dart';
import 'product_variant_model.dart';

class DirectPurchaseData {
  final ProductModel product;
  final ProductVariantModel? variant;
  final int quantity;

  const DirectPurchaseData({
    required this.product,
    required this.variant,
    required this.quantity,
  });

  double get unitPrice {
    return variant?.getEffectivePrice(product.price) ?? product.price;
  }

  double get totalPrice {
    return unitPrice * quantity;
  }

  String get productName {
    return product.name;
  }

  String? get imageUrl {
    return variant?.imageUrl ?? product.imageUrl;
  }

  String? get variantName {
    return variant?.displayName;
  }
}
