import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_model.dart';
import 'product_repository.dart';

enum CompareAddResult {
  added,
  alreadyAdded,
  limitReached,
  differentType,
  productUnavailable,
}

class CompareRepository {
  static const String _storageKeyPrefix = 'compared_product_ids';

  static const int maxProducts = 4;

  String get _storageKey {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      return '${_storageKeyPrefix}_guest';
    }

    return '${_storageKeyPrefix}_$userId';
  }

  // Shared notification for all screens using comparison.
  static final ValueNotifier<int> comparisonChanges = ValueNotifier<int>(0);

  final ProductRepository _productRepository = ProductRepository();

  // Notify all listening screens whenever comparison changes.
  static void _notifyChanges() {
    comparisonChanges.value++;
  }

  /// Check whether two products belong to the same comparison group.
  bool _hasSameProductType(ProductModel first, ProductModel second) {
    final firstCategory = first.category.trim().toLowerCase();
    final secondCategory = second.category.trim().toLowerCase();

    if (firstCategory != secondCategory) {
      return false;
    }

    final firstType = first.productType?.trim().toLowerCase() ?? '';
    final secondType = second.productType?.trim().toLowerCase() ?? '';

    // If both product types are missing, compare by category.
    if (firstType.isEmpty && secondType.isEmpty) {
      return true;
    }

    return firstType.isNotEmpty &&
        secondType.isNotEmpty &&
        firstType == secondType;
  }

  /// Get saved comparison product IDs.
  Future<List<String>> getComparedProductIds() async {
    final preferences = await SharedPreferences.getInstance();

    return preferences.getStringList(_storageKey) ?? [];
  }

  /// Get complete product details and clean outdated or incompatible IDs.
  Future<List<ProductModel>> getComparedProducts() async {
    final preferences = await SharedPreferences.getInstance();

    final productIds = preferences.getStringList(_storageKey) ?? [];

    if (productIds.isEmpty) {
      return [];
    }

    final products = await Future.wait(
      productIds.map(_productRepository.getProductById),
    );

    final validProducts = products.whereType<ProductModel>().toList();

    // Keep only products belonging to the first valid product type.
    final cleanedProducts = <ProductModel>[];

    if (validProducts.isNotEmpty) {
      final referenceProduct = validProducts.first;

      for (final product in validProducts) {
        if (_hasSameProductType(referenceProduct, product)) {
          cleanedProducts.add(product);
        }
      }
    }

    final cleanedIds = cleanedProducts.map((product) => product.id).toList();

    if (!listEquals(productIds, cleanedIds)) {
      if (cleanedIds.isEmpty) {
        await preferences.remove(_storageKey);
      } else {
        await preferences.setStringList(_storageKey, cleanedIds);
      }

      _notifyChanges();
    }

    return cleanedProducts;
  }

  /// Add a product to the comparison list.
  Future<CompareAddResult> addProduct(String productId) async {
    final product = await _productRepository.getProductById(productId);

    if (product == null) {
      return CompareAddResult.productUnavailable;
    }

    final preferences = await SharedPreferences.getInstance();

    final productIds = preferences.getStringList(_storageKey) ?? [];

    if (productIds.contains(productId)) {
      return CompareAddResult.alreadyAdded;
    }

    // Load existing products and remove outdated or incompatible IDs.
    final existingProducts = await Future.wait(
      productIds.map(_productRepository.getProductById),
    );

    final validProducts = existingProducts.whereType<ProductModel>().toList();

    final compatibleProducts = <ProductModel>[];

    if (validProducts.isNotEmpty) {
      final referenceProduct = validProducts.first;

      for (final existingProduct in validProducts) {
        if (_hasSameProductType(referenceProduct, existingProduct)) {
          compatibleProducts.add(existingProduct);
        }
      }
    }

    final cleanedIds = compatibleProducts.map((item) => item.id).toList();

    final storageChanged = !listEquals(productIds, cleanedIds);

    if (storageChanged) {
      if (cleanedIds.isEmpty) {
        await preferences.remove(_storageKey);
      } else {
        await preferences.setStringList(_storageKey, cleanedIds);
      }
    }

    // Reject products from a different category or product type.
    if (compatibleProducts.isNotEmpty &&
        !_hasSameProductType(compatibleProducts.first, product)) {
      if (storageChanged) {
        _notifyChanges();
      }

      return CompareAddResult.differentType;
    }

    if (cleanedIds.length >= maxProducts) {
      if (storageChanged) {
        _notifyChanges();
      }

      return CompareAddResult.limitReached;
    }

    cleanedIds.add(productId);

    await preferences.setStringList(_storageKey, cleanedIds);

    _notifyChanges();

    return CompareAddResult.added;
  }

  /// Remove a product from comparison.
  Future<void> removeProduct(String productId) async {
    final preferences = await SharedPreferences.getInstance();

    final productIds = preferences.getStringList(_storageKey) ?? [];

    final wasRemoved = productIds.remove(productId);

    if (wasRemoved) {
      await preferences.setStringList(_storageKey, productIds);
      _notifyChanges();
    }
  }

  /// Remove all compared products.
  Future<void> clearComparison() async {
    final preferences = await SharedPreferences.getInstance();

    final productIds = preferences.getStringList(_storageKey) ?? [];

    if (productIds.isEmpty) return;

    await preferences.remove(_storageKey);

    _notifyChanges();
  }

  /// Get the current comparison count.
  Future<int> getComparisonCount() async {
    final productIds = await getComparedProductIds();

    return productIds.length;
  }

  /// Check whether a product is already being compared.
  Future<bool> isProductCompared(String productId) async {
    final productIds = await getComparedProductIds();

    return productIds.contains(productId);
  }
}
