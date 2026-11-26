import 'product_model.dart';
import 'product_variant_model.dart';

class CartItemModel {
  final String id;
  final String cartId;
  final String productId;
  final String? variantId;
  final int quantity;
  final ProductModel product;
  final ProductVariantModel? variant;

  const CartItemModel({
    required this.id,
    required this.cartId,
    required this.productId,
    this.variantId,
    required this.quantity,
    required this.product,
    this.variant,
  });

  /// Uses the variant price when available; otherwise uses the product price.
  double get effectivePrice {
    return variant?.getEffectivePrice(product.price) ?? product.price;
  }

  /// Uses variant stock when a variant is selected.
  int get availableStock {
    return variant?.stockQuantity ?? product.stockQuantity;
  }

  /// Uses the variant image when available.
  String? get displayImageUrl {
    return variant?.imageUrl ?? product.imageUrl;
  }

  /// Human-readable selected variant attributes.
  String? get variantDisplayName {
    if (variant == null || variant!.attributes.isEmpty) {
      return null;
    }

    return variant!.displayName;
  }

  double get totalPrice => effectivePrice * quantity;

  factory CartItemModel.fromMap(Map<String, dynamic> map) {
    final productData = map['products'];

    if (productData == null) {
      throw const FormatException(
        'Product information is missing from cart item.',
      );
    }

    final variantData = map['product_variants'];

    return CartItemModel(
      id: map['id'] as String,
      cartId: map['cart_id'] as String,
      productId: map['product_id'] as String,
      variantId: map['variant_id'] as String?,
      quantity: (map['quantity'] as num).toInt(),
      product: ProductModel.fromMap(
        Map<String, dynamic>.from(productData as Map),
      ),
      variant: variantData == null
          ? null
          : ProductVariantModel.fromMap(
              Map<String, dynamic>.from(variantData as Map),
            ),
    );
  }
}
