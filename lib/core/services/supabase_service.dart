
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
SupabaseService._();

/// Provides access to the initialized Supabase client.
static SupabaseClient get client => Supabase.instance.client;

/// Initializes Supabase before the application starts.
static Future<void> initialize({
required String supabaseUrl,
required String publishableKey,
}) async {
await Supabase.initialize(
url: supabaseUrl,
publishableKey: publishableKey,
);
}

/// Returns the currently authenticated user, if one exists.
static User? get currentUser => client.auth.currentUser;

/// Indicates whether a user is currently authenticated.
static bool get isAuthenticated => currentUser != null;
}